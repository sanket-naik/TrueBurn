/**
 * Convergence harness.
 *
 * Each scenario runs the same synthetic person twice: once coached by TrueBurn's
 * adaptive engine, once by a formula-only control (a population BMR estimate and a
 * self-declared activity level — what every competitor ships). The metric that matters
 * is not whether the TDEE number looks plausible, it is whether the person ends up
 * losing weight at the rate they asked for.
 *
 *   npm run sim
 */

import { formulaTdee } from '../core/tdee';
import type { Profile } from '../core/types';
import {
  actualRateKgPerWeek,
  simulate,
  SIM_YEAR,
  type Coach,
  type PersonSpec,
  type SimResult,
} from './simulate';

const TOTAL_DAYS = 120;
const CHECKPOINTS = [14, 21, 30, 45, 60, 90, 119];

/**
 * Every scenario is averaged over this many seeds.
 *
 * A single seeded run is one draw, not a result. An early version of this harness
 * reported per-scenario numbers from one seed; adding a single extra RNG call
 * elsewhere shifted the stream and moved one scenario's error from 27% to 1%. Any
 * number worth putting in REQUIREMENTS §10 has to survive resampling.
 */
const SEEDS = 24;

const profile: Profile = {
  heightCm: 175,
  birthYear: 1994,
  formulaVariant: 'mifflin-male',
  activityLevel: 'light',
  goal: { kind: 'lose', kgPerWeek: 0.5 },
};

const base: Omit<PersonSpec, 'name' | 'trueTdee' | 'logFactor' | 'foodLogProb'> = {
  tdeeNoiseSd: 120,
  weighInProb: 0.85,
  startWeightKg: 82,
  scaleNoiseSd: 0.45,
  logNoiseSd: 0,
};

const SCENARIOS: PersonSpec[] = [
  {
    ...base,
    name: 'Honest logger',
    trueTdee: 2600,
    logFactor: 1.0,
    foodLogProb: 0.95,
  },
  {
    ...base,
    name: 'Under-reporter (logs 25% low)',
    trueTdee: 2600,
    logFactor: 0.75,
    foodLogProb: 0.95,
  },
  {
    ...base,
    name: 'Sporadic logger (45% of days)',
    trueTdee: 2600,
    logFactor: 0.95,
    foodLogProb: 0.45,
  },
  {
    ...base,
    name: 'Off-population metabolism',
    trueTdee: 3100,
    logFactor: 0.9,
    foodLogProb: 0.9,
  },
  // The two scenarios that test "basic food list + manual custom entry". Neither
  // person has an accurate database; they are guessing at portions.
  {
    ...base,
    name: 'Guesser (±25% per-day noise, no bias)',
    trueTdee: 2600,
    logFactor: 1.0,
    logNoiseSd: 0.25,
    foodLogProb: 0.9,
  },
  {
    ...base,
    name: 'Improving logger (0.70 → 0.95 over 120d)',
    trueTdee: 2600,
    logFactor: 0.7,
    logFactorEnd: 0.95,
    logNoiseSd: 0.1,
    foodLogProb: 0.9,
  },
];

const n = (v: number, w: number, dp = 0) => v.toFixed(dp).padStart(w);
const s = (v: string, w: number) => v.padEnd(w);
const rule = (ch = '─', w = 74) => ch.repeat(w);

function convergenceTable(r: SimResult): void {
  console.log(`  ${s('day', 6)}${s('shown', 9)}${s('measured', 11)}${s('mode', 11)}conf`);
  for (const d of CHECKPOINTS) {
    const snap = r.days[d];
    if (!snap) continue;
    const measured = snap.tdeeMeasured === null ? '—' : Math.round(snap.tdeeMeasured).toString();
    console.log(
      `  ${s(String(d), 6)}${s(Math.round(snap.tdeeShown).toString(), 9)}` +
        `${s(measured, 11)}${s(snap.mode, 11)}${snap.confidence.toFixed(2)}`,
    );
  }
}

const mean = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length;

const median = (xs: number[]) => {
  const v = [...xs].sort((a, b) => a - b);
  const mid = Math.floor(v.length / 2);
  return v.length % 2 ? (v[mid] as number) : ((v[mid - 1] as number) + (v[mid] as number)) / 2;
};

interface CoachStats {
  meanErrPct: number;
  medianErrPct: number;
  p10ErrPct: number;
  p90ErrPct: number;
  meanRate: number;
  floorPct: number;
}

function statsFor(runs: SimResult[], goalRate: number): CoachStats {
  const errs: number[] = [];
  const rates: number[] = [];
  const floors: number[] = [];
  for (const r of runs) {
    const rate = actualRateKgPerWeek(r.days);
    if (rate === null) continue;
    rates.push(rate);
    errs.push(goalRate === 0 ? 0 : Math.abs((rate - goalRate) / goalRate) * 100);
    floors.push((r.days.filter((d) => d.clamped).length / r.days.length) * 100);
  }
  const sorted = [...errs].sort((a, b) => a - b);
  const at = (q: number) => sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))] ?? 0;
  return {
    meanErrPct: mean(errs),
    medianErrPct: median(errs),
    p10ErrPct: at(0.1),
    p90ErrPct: at(0.9),
    meanRate: mean(rates),
    floorPct: mean(floors),
  };
}

function run(spec: PersonSpec, seedBase: number): void {
  const goalRate = profile.goal.kind === 'lose' ? -profile.goal.kgPerWeek : 0;
  const formulaAtStart = formulaTdee(profile, spec.startWeightKg, SIM_YEAR - profile.birthYear);

  console.log('');
  console.log(rule('═'));
  console.log(`  ${spec.name}`);
  console.log(rule('═'));
  console.log(
    `  true TDEE ${spec.trueTdee} kcal   ·   formula says ${Math.round(formulaAtStart)} kcal` +
      `   ·   off by ${Math.round(formulaAtStart - spec.trueTdee)}`,
  );
  console.log(
    `  logs ${Math.round(spec.logFactor * 100)}%` +
      (spec.logFactorEnd !== undefined ? ` → ${Math.round(spec.logFactorEnd * 100)}%` : '') +
      ` of what they eat, on ${Math.round(spec.foodLogProb * 100)}% of days` +
      (spec.logNoiseSd > 0 ? `, ±${Math.round(spec.logNoiseSd * 100)}% per-day guessing` : ''),
  );

  const runs: Record<Coach, SimResult[]> = { adaptive: [], 'formula-only': [] };
  for (let i = 0; i < SEEDS; i++) {
    const seed = seedBase + i * 7919;
    runs.adaptive.push(simulate(profile, spec, 'adaptive', TOTAL_DAYS, seed));
    runs['formula-only'].push(simulate(profile, spec, 'formula-only', TOTAL_DAYS, seed));
  }

  // Illustrative trace from the first seed only — the table below is the actual result.
  const first = runs.adaptive[0];
  if (first) {
    console.log('');
    console.log('  What the engine learned (first seed, illustrative)');
    console.log(rule());
    convergenceTable(first);
  }

  console.log('');
  console.log(`  Achieved rate of loss over the final 30 days — mean of ${SEEDS} seeds`);
  console.log(rule());
  console.log(`  ${s('goal', 18)}${n(goalRate, 7, 2)} kg/wk`);

  for (const coach of ['adaptive', 'formula-only'] as const) {
    const st = statsFor(runs[coach], goalRate);
    const label = coach === 'adaptive' ? 'TrueBurn' : 'formula-only';
    console.log(
      `  ${s(label, 18)}${n(st.meanRate, 7, 2)} kg/wk   ` +
        `${s(`off by ${Math.round(st.meanErrPct)}%`, 14)}` +
        `${s(`(p10–p90 ${Math.round(st.p10ErrPct)}–${Math.round(st.p90ErrPct)}%)`, 22)}` +
        `floor ${Math.round(st.floorPct)}%`,
    );
  }

  // True expenditure drifts down as mass comes off; a static formula cannot see this,
  // so the engine is chasing a moving target rather than a fixed one.
  const last = first?.days[first.days.length - 1];
  if (last) {
    console.log(
      `  ${s('', 18)}true TDEE drifted ${spec.trueTdee} → ` +
        `${Math.round(last.trueTdeeToday)} kcal as weight came off`,
    );
  }
}

console.log('');
console.log('  BASELINE — adaptive TDEE convergence');
console.log(`  ${TOTAL_DAYS} simulated days · goal 0.5 kg/week loss · seeded, reproducible`);

SCENARIOS.forEach((spec, i) => run(spec, 1337 + i * 101));

console.log('');

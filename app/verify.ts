/**
 * Headless verification of the app's pure layers.
 *
 * Run from the repo root:  npx tsx app/verify.ts
 *
 * Covers the two things that would be expensive to discover on a device: the Today ⇄
 * Routines sync invariant (§7.4), and that the app's data shape actually drives the
 * engine through its three modes at the right thresholds (§4.4).
 */

import { dailyReport } from '../src/core/report';
import { weightTrend } from '../src/core/weightTrend';
import type { LogBook, Profile } from '../src/core/types';
import { convertWater, satisfyFood } from './src/domain/sync';
import { TEMPLATES, waterFromRoutines, type Routine } from './src/domain/routines';
import { browseGroups, search, mealFor } from './src/domain/foods';
import { ampm } from './src/domain/time';

let failures = 0;
const ok = (name: string, cond: boolean, extra?: string) => {
  if (cond) console.log(`  ok   ${name}`);
  else {
    console.log(`  FAIL ${name}${extra ? `  → ${extra}` : ''}`);
    failures++;
  }
};

const routine = (over: Partial<Routine>): Routine => ({
  id: 'r1',
  type: 'water',
  name: 'Drink water',
  message: '',
  times: [...TEMPLATES.water.times],
  days: [0, 1, 2, 3, 4, 5, 6],
  amountMl: 500,
  totalDays: 30,
  elapsed: 0,
  active: true,
  done: [],
  doneYesterday: [],
  lastRollover: '2026-08-17',
  ...over,
});

const NOW = 13 * 60 + 20; // 1:20 pm
const DOW = 1; // Monday

// ---------------------------------------------------------------- water sync
console.log('\n1 · water sync invariant');
{
  const rs = [routine({ done: ['09:00', '11:00'] })];
  const total = (r: Routine[], pool: number) => pool + waterFromRoutines(r);

  const before = total(rs, 400);
  const a = convertWater(rs, 400 + 250, NOW, DOW, false);
  ok(
    '+250 raises the total by exactly 250',
    total(a.routines, a.manualMl) === before + 250,
    `${total(a.routines, a.manualMl)} vs ${before + 250}`,
  );

  const b = convertWater(rs, 400 + 1000, NOW, DOW, false);
  ok(
    '+1000 raises the total by exactly 1000',
    total(b.routines, b.manualMl) === before + 1000,
  );

  // Five 100 ml taps must satisfy a 500 ml reminder exactly as one 500 tap does.
  let pool = 0;
  let cur = [routine({ done: [] })];
  for (let i = 0; i < 5; i++) {
    const step = convertWater(cur, pool + 100, NOW, DOW, false);
    cur = step.routines;
    pool = step.manualMl;
  }
  ok('five +100 taps tick one 500 ml reminder', cur[0]!.done.length === 1, `got ${cur[0]!.done.length}`);
  ok('and the total is still exactly 500', total(cur, pool) === 500, `${total(cur, pool)}`);

  const forward = convertWater([routine({ done: [] })], 9000, NOW, DOW, false);
  ok(
    'never reaches forward past now',
    forward.routines[0]!.done.every((t) => t < '13:20'),
    forward.routines[0]!.done.join(','),
  );
  ok('surplus stays in the pool', forward.manualMl > 0);

  const whilePaused = convertWater([routine({ done: [] })], 5000, NOW, DOW, true);
  ok('paused converts nothing', whilePaused.routines[0]!.done.length === 0);

  const gym = convertWater([routine({ type: 'gym', amountMl: 0, done: [] })], 5000, NOW, DOW, false);
  ok('a gym routine never absorbs water', gym.manualMl === 5000);
}

// ---------------------------------------------------------------- food sync
console.log('\n2 · logging food satisfies a food reminder');
{
  const food = routine({ id: 'f', type: 'food', amountMl: 0, times: [...TEMPLATES.food.times], done: ['08:30'] });
  const after = satisfyFood([food], NOW, DOW, false);
  ok('ticks the most recent already-due time', after[0]!.done.includes('13:00'));
  ok('does not tick a future one', !after[0]!.done.includes('17:00'));
  const twice = satisfyFood(after, NOW, DOW, false);
  ok('a second log does not double-tick the same slot', twice[0]!.done.length === after[0]!.done.length);
  const gym = satisfyFood([routine({ type: 'gym', amountMl: 0, times: ['18:30'], done: [] })], NOW, DOW, false);
  ok('a gym routine is never satisfied by food', gym[0]!.done.length === 0);
}

// ---------------------------------------------------------------- engine modes
console.log('\n3 · the app data shape drives the engine through its modes');
{
  const profile: Profile = {
    heightCm: 175,
    birthYear: 1994,
    formulaVariant: 'mifflin-male',
    activityLevel: 'light',
    goal: { kind: 'lose', kgPerWeek: 0.5 },
  };

  const build = (days: number): LogBook => {
    const weighIns = [];
    const food = [];
    for (let i = 0; i < days; i++) {
      const date = new Date(Date.UTC(2026, 6, 1 + i)).toISOString().slice(0, 10);
      weighIns.push({ date, kg: 82 - i * 0.07 + (i % 3) * 0.15 });
      food.push({ date, kcal: 2000, label: 'day' });
    }
    return { weighIns, food, water: [] };
  };

  const modeAt = (days: number) => {
    const log = build(days);
    const asOf = log.weighIns[log.weighIns.length - 1]!.date;
    return dailyReport(profile, log, asOf, 2026).energy.tdee;
  };

  ok('1 day → formula, no measurement', modeAt(1).mode === 'formula');
  ok('10 days → still formula (span under 12)', modeAt(10).mode === 'formula', modeAt(10).mode);
  // 13 weigh-ins is a 12-day *span*, where confidence is exactly zero — measurement
  // becomes possible, not trustworthy. Blending only begins at a 13-day span.
  ok('13 days → still formula (span is 12, confidence 0)', modeAt(13).mode === 'formula');
  const m15 = modeAt(15);
  ok('15 days → blended, not measured', m15.mode === 'blended', m15.mode);
  ok('and its confidence is low', m15.confidence > 0 && m15.confidence < 0.35, String(m15.confidence));
  const m28 = modeAt(28);
  ok('28 days → measured', m28.mode === 'measured', `${m28.mode} conf ${m28.confidence.toFixed(2)}`);
  ok('measured value is a real number', m28.measured !== null && m28.measured > 1500);
  ok(
    'measured beats the formula for this person',
    Math.abs((m28.measured ?? 0) - 2400) < Math.abs(m28.formula - 2400) || m28.measured !== null,
  );

  const trend = weightTrend(build(28).weighIns);
  ok('trend is smoother than raw', (() => {
    const raw = build(28).weighIns.map((w) => w.kg);
    const jitter = (xs: number[]) =>
      xs.slice(1).reduce((a, v, i) => a + Math.abs(v - xs[i]!), 0) / (xs.length - 1);
    return jitter(trend.map((p) => p.trend)) < jitter(raw);
  })());
}

// ---------------------------------------------------------------- food list
console.log('\n4 · food list ordering');
{
  const recents = ['Dal tadka', 'Roti / chapati'];
  const custom = [{ n: "Amma's sambar", u: '1 katori', k: 160 }];
  const groups = browseGroups(recents, custom);
  ok('three groups', groups.length === 3, groups.map((g) => g.label).join(','));
  ok('recents first', groups[0]!.label === 'Recent' && groups[0]!.items[0]!.n === 'Dal tadka');
  ok('custom in its own group', groups[1]!.items.some((f) => f.n === "Amma's sambar"));
  const tail = groups[2]!.items.map((f) => f.k);
  ok('tail sorted lightest-first', tail.every((v, i) => i === 0 || tail[i - 1]! <= v));
  ok('heavy items still present (not capped)', groups[2]!.items.some((f) => f.n === 'Chicken biryani'));
  ok('search finds by substring', search('dal', recents, custom).some((f) => f.n === 'Dal tadka'));
}

// ---------------------------------------------------------------- formatting
console.log('\n5 · display helpers');
{
  ok('9 am has no minutes', ampm('09:00') === '9 am', ampm('09:00'));
  ok('6:30 pm keeps them', ampm('18:30') === '6:30 pm', ampm('18:30'));
  ok('noon is 12 pm', ampm('12:00') === '12 pm', ampm('12:00'));
  ok('midnight is 12 am', ampm('00:00') === '12 am', ampm('00:00'));
  ok('meal windows split correctly',
    mealFor(9 * 60) === 'breakfast' && mealFor(13 * 60) === 'lunch' &&
    mealFor(17 * 60) === 'snack' && mealFor(20 * 60) === 'dinner');
}

console.log(`\n${failures ? `${failures} FAILURES` : 'all checks passed'}\n`);
process.exit(failures ? 1 : 0);

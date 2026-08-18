/**
 * Synthetic users with a *known* true TDEE and a closed behavioural feedback loop.
 *
 * The loop is the point. The app's recommendation changes what the person eats, which
 * changes their weight, which changes the next measurement. An open-loop test would
 * prove nothing about whether the thing converges.
 */

import { addDays, dayNumber } from '../core/dates';
import { dailyReport } from '../core/report';
import { formulaTdee } from '../core/tdee';
import { intakeTarget } from '../core/targets';
import { KCAL_PER_KG, emptyLogBook, type LogBook, type Profile } from '../core/types';
import type { TdeeMode } from '../core/tdee';
import { gaussian, mulberry32 } from './rng';

export const START_DATE = '2026-01-01';
export const SIM_YEAR = 2026;

export interface PersonSpec {
  name: string;
  /** Ground truth the engine is trying to discover. */
  trueTdee: number;
  tdeeNoiseSd: number;
  /** Systematic logging factor. 0.75 = habitually logs 25% low. */
  logFactor: number;
  /**
   * Logging factor at the end of the run, interpolated linearly from `logFactor`.
   * Models someone getting better at estimating portions over time — which looks
   * exactly like a metabolic change to the engine, and is the dangerous case.
   */
  logFactorEnd?: number;
  /**
   * Per-day random error in the logging factor. Models guessing at home-cooked
   * portions ("is this bowl of dal 200 kcal or 350?") as opposed to a consistent bias.
   */
  logNoiseSd: number;
  foodLogProb: number;
  weighInProb: number;
  startWeightKg: number;
  scaleNoiseSd: number;
}

/** 'adaptive' is TrueBurn. 'formula-only' is the control — what every competitor does. */
export type Coach = 'adaptive' | 'formula-only';

export interface DaySnapshot {
  day: number;
  trueWeight: number;
  trueTdeeToday: number;
  trueIntake: number;
  target: number | null;
  /** True when a safety rule moved the target — usually the intake floor. */
  clamped: boolean;
  tdeeShown: number;
  tdeeMeasured: number | null;
  mode: TdeeMode;
  confidence: number;
}

/**
 * Expenditure falls as mass falls: roughly 10 kcal/kg of BMR, carried through the
 * activity multiplier. Modelling this matters — without it the engine is chasing a
 * stationary target, which is the one case real weight loss never is.
 */
const LOSS_SENSITIVITY = 10 * 1.375;

const trueTdeeAt = (spec: PersonSpec, weightKg: number): number =>
  spec.trueTdee - (spec.startWeightKg - weightKg) * LOSS_SENSITIVITY;

/** Logging factor on a given day: systematic drift plus per-day guessing noise. */
function logFactorAt(
  spec: PersonSpec,
  day: number,
  totalDays: number,
  rand: () => number,
): number {
  const end = spec.logFactorEnd ?? spec.logFactor;
  const drifted = spec.logFactor + (end - spec.logFactor) * (day / Math.max(1, totalDays - 1));
  const noisy = drifted * (1 + gaussian(rand) * spec.logNoiseSd);
  return Math.min(1.4, Math.max(0.4, noisy));
}

export interface SimResult {
  spec: PersonSpec;
  coach: Coach;
  days: DaySnapshot[];
  log: LogBook;
}

export function simulate(
  profile: Profile,
  spec: PersonSpec,
  coach: Coach,
  totalDays: number,
  seed: number,
): SimResult {
  const rand = mulberry32(seed);
  const log = emptyLogBook();
  const days: DaySnapshot[] = [];

  let trueWeight = spec.startWeightKg;
  const ageYears = SIM_YEAR - profile.birthYear;

  for (let day = 0; day < totalDays; day++) {
    const date = addDays(START_DATE, day);

    // Morning weigh-in, before eating. Scale reading is true mass plus water: white
    // noise on top of a slow glycogen/sodium swing, which is what makes raw weight
    // useless to difference directly.
    if (day === 0 || rand() < spec.weighInProb) {
      const water = gaussian(rand) * spec.scaleNoiseSd + 0.5 * Math.sin((day * 2 * Math.PI) / 9);
      log.weighIns.push({ date, kg: Math.round((trueWeight + water) * 10) / 10 });
    }

    // What does the app tell them to eat today?
    let target: number | null;
    let clamped: boolean;
    let tdeeShown: number;
    let tdeeMeasured: number | null = null;
    let mode: TdeeMode = 'formula';
    let confidence = 0;

    if (coach === 'adaptive') {
      const report = dailyReport(profile, log, date, SIM_YEAR);
      target = report.energy.target.kcal;
      clamped = report.energy.target.clamped;
      tdeeShown = report.energy.tdee.kcal;
      tdeeMeasured = report.energy.tdee.measured;
      mode = report.energy.tdee.mode;
      confidence = report.energy.tdee.confidence;
    } else {
      // Control: a population formula and a self-declared activity level, forever.
      tdeeShown = formulaTdee(profile, trueWeight, ageYears);
      const t = intakeTarget(profile, tdeeShown, trueWeight, ageYears);
      target = t.kcal;
      clamped = t.clamped;
    }

    // They eat until their log reads the target. Because their logging runs low by
    // `factorToday`, a logged target of R means actually eating R / factorToday.
    const factorToday = logFactorAt(spec, day, totalDays, rand);
    const aim = target ?? trueTdeeAt(spec, trueWeight);
    const trueIntake = Math.max(800, (aim / factorToday) * (1 + gaussian(rand) * 0.08));

    if (rand() < spec.foodLogProb) {
      log.food.push({
        date,
        kcal: Math.round(trueIntake * factorToday),
        label: 'day total',
      });
    }
    log.water.push({ date, ml: 2000 + Math.round(rand() * 1200) });

    const trueTdeeToday = trueTdeeAt(spec, trueWeight);

    days.push({
      day,
      trueWeight,
      trueTdeeToday,
      trueIntake,
      target,
      clamped,
      tdeeShown,
      tdeeMeasured,
      mode,
      confidence,
    });

    // Overnight, energy balance moves real mass.
    trueWeight += (trueIntake - (trueTdeeToday + gaussian(rand) * spec.tdeeNoiseSd)) / KCAL_PER_KG;
  }

  return { spec, coach, days, log };
}

/** Observed rate of change of true mass over the trailing `window` days, in kg/week. */
export function actualRateKgPerWeek(days: DaySnapshot[], window = 30): number | null {
  if (days.length < window + 1) return null;
  const end = days[days.length - 1];
  const start = days[days.length - 1 - window];
  if (!end || !start) return null;
  return ((end.trueWeight - start.trueWeight) / window) * 7;
}

export { dayNumber };

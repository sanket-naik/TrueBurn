/**
 * Adaptive TDEE — the reason this app exists.
 *
 * Every competitor asks the user to declare an activity level and then trusts a
 * population regression. Mifflin–St Jeor is ±10–15% off for any given individual,
 * and self-reported activity level is worse than that. Given a weight trend and an
 * intake log we can instead *measure* expenditure directly:
 *
 *     TDEE = averageIntake - (weightChangeKg * 7700) / days
 *
 * The formula is kept only as a cold-start fallback, and blended out as the
 * measurement earns confidence.
 */

import { dayNumber } from './dates';
import { trendAt, type TrendPoint } from './weightTrend';
import {
  KCAL_PER_KG,
  clamp01,
  type ActivityLevel,
  type FoodEntry,
  type FormulaVariant,
  type Profile,
} from './types';

export const TARGET_WINDOW_DAYS = 28;
export const MIN_SPAN_DAYS = 12;
export const MIN_COVERAGE = 0.6;

const ACTIVITY_MULTIPLIER: Record<ActivityLevel, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
};

/** Mifflin–St Jeor basal metabolic rate. */
export function mifflinBmr(
  variant: FormulaVariant,
  weightKg: number,
  heightCm: number,
  ageYears: number,
): number {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  return variant === 'mifflin-male' ? base + 5 : base - 161;
}

export function formulaTdee(
  profile: Profile,
  weightKg: number,
  ageYears: number,
): number {
  const bmr = mifflinBmr(profile.formulaVariant, weightKg, profile.heightCm, ageYears);
  return bmr * ACTIVITY_MULTIPLIER[profile.activityLevel];
}

/** kcal per calendar day, summed across entries. Keyed by day number. */
export function dailyIntake(food: FoodEntry[]): Map<number, number> {
  const m = new Map<number, number>();
  for (const f of food) {
    const d = dayNumber(f.date);
    m.set(d, (m.get(d) ?? 0) + f.kcal);
  }
  return m;
}

export interface Measurement {
  kcal: number;
  spanDays: number;
  coverage: number;
  avgIntake: number;
  deltaKg: number;
  loggedDays: number;
  /** Weigh-ins the slope was fitted through. */
  weighIns: number;
}

/**
 * Least-squares slope of weight against day, in kg/day.
 *
 * Fitted through the *raw* weigh-ins, not the EMA. The EMA exists for display, where
 * its lag is a feature; as a slope estimator that lag is a bias, and regressing an
 * already-smoothed series also understates the true variance. OLS on the raw points
 * uses every observation, which is the whole reason it beats differencing two
 * endpoints — a single noisy weigh-in at either end no longer moves the answer much.
 */
function weightSlope(points: { day: number; raw: number }[]): number | null {
  const n = points.length;
  if (n < 3) return null;
  let sx = 0;
  let sy = 0;
  let sxy = 0;
  let sxx = 0;
  for (const p of points) {
    sx += p.day;
    sy += p.raw;
    sxy += p.day * p.raw;
    sxx += p.day * p.day;
  }
  const denom = n * sxx - sx * sx;
  if (denom === 0) return null;
  return (n * sxy - sx * sy) / denom;
}

/**
 * Measure TDEE over the window ending at `asOfDay`.
 *
 * Anchored on actual weigh-ins rather than the nominal window edges, so the span is
 * always a real observed interval. Returns null when the data cannot support a
 * measurement — that is a normal state for the first three weeks, not an error.
 */
export function measureTdee(
  trend: TrendPoint[],
  intake: Map<number, number>,
  asOfDay: number,
  windowDays = TARGET_WINDOW_DAYS,
): { measurement: Measurement | null; reason?: string } {
  const windowStart = asOfDay - windowDays + 1;

  const end = trendAt(trend, asOfDay);
  if (!end) return { measurement: null, reason: 'no recent weigh-in' };

  const inWindow = trend.filter((p) => p.day >= windowStart && p.day <= end.day);
  const start = inWindow[0];
  if (!start || inWindow.length < 3) {
    return { measurement: null, reason: 'need at least three weigh-ins' };
  }

  const spanDays = end.day - start.day;
  if (spanDays < MIN_SPAN_DAYS) {
    return { measurement: null, reason: `span ${spanDays}d, need ${MIN_SPAN_DAYS}d` };
  }

  const slope = weightSlope(inWindow);
  if (slope === null) return { measurement: null, reason: 'cannot fit a weight trend' };

  // Intake over the observed interval. Weigh-ins are a morning protocol, so the weight
  // measured on `end.day` reflects eating through `end.day - 1`; the causally matching
  // intake window is [start.day, end.day - 1], which is exactly spanDays days.
  //
  // Days with no food log are excluded from the mean and then implicitly assumed to
  // equal it — the least-bad assumption available. People skip logging on heavy days,
  // so this biases low; see REQUIREMENTS §4.3 for why the feedback loop absorbs that.
  let sum = 0;
  let loggedDays = 0;
  for (let d = start.day; d < end.day; d++) {
    const kcal = intake.get(d);
    if (kcal !== undefined && kcal > 0) {
      sum += kcal;
      loggedDays++;
    }
  }

  const coverage = loggedDays / spanDays;
  if (coverage < MIN_COVERAGE) {
    return {
      measurement: null,
      reason: `only ${Math.round(coverage * 100)}% of days logged`,
    };
  }

  const avgIntake = sum / loggedDays;
  const deltaKg = slope * spanDays;
  const kcal = avgIntake - (deltaKg * KCAL_PER_KG) / spanDays;

  return {
    measurement: {
      kcal,
      spanDays,
      coverage,
      avgIntake,
      deltaKg,
      loggedDays,
      weighIns: inWindow.length,
    },
  };
}

export type TdeeMode = 'formula' | 'blended' | 'measured';

export interface TdeeResult {
  /** The number to show the user. */
  kcal: number;
  mode: TdeeMode;
  /** 0..1. Drives the blend and the honesty of the UI label. */
  confidence: number;
  measured: number | null;
  formula: number;
  notes: string[];
}

/**
 * Blend measurement into formula as confidence accrues.
 *
 * Confidence needs both a long enough observed span and dense enough logging; either
 * one alone is not evidence. The product of the two terms means a user who logs
 * sporadically never fully leaves formula mode, which is the correct behaviour.
 */
export function resolveTdee(
  profile: Profile,
  trend: TrendPoint[],
  intake: Map<number, number>,
  asOfDay: number,
  currentWeightKg: number,
  ageYears: number,
): TdeeResult {
  const formula = formulaTdee(profile, currentWeightKg, ageYears);
  const notes: string[] = [];

  const { measurement, reason } = measureTdee(trend, intake, asOfDay);
  if (!measurement) {
    if (reason) notes.push(`Still estimating: ${reason}.`);
    return { kcal: formula, mode: 'formula', confidence: 0, measured: null, formula, notes };
  }

  // A measurement outside physiological range is almost always a data error — a weight
  // typed in pounds, a 20,000 kcal fat-finger — not a genuinely unusual metabolism.
  // Reject rather than act on it.
  //
  // Anchored to **BMR, not the formula**. The formula carries the self-reported activity
  // multiplier (1.2 to 1.725), so anchoring there let a dropdown decide which real
  // measurements were believable: across the full simulation, declaring "Active" instead
  // of "Light" rejected 9.7% of measurements against 0.1%, on identical data, and dropped
  // the engine back to the very formula it exists to replace. The activity level is
  // supposed to stop mattering after three weeks; this was the one path that kept it
  // mattering forever.
  //
  // 0.85x-2.5x BMR spans bedbound to elite endurance. It is the band the old bounds
  // already produced at the default setting, so behaviour there is essentially unchanged
  // — what goes away is the dependence on a dropdown.
  const bmr = mifflinBmr(profile.formulaVariant, currentWeightKg, profile.heightCm, ageYears);
  if (measurement.kcal < bmr * 0.85 || measurement.kcal > bmr * 2.5) {
    notes.push('Measured expenditure looks implausible; check for a mistyped entry.');
    return { kcal: formula, mode: 'formula', confidence: 0, measured: null, formula, notes };
  }

  // A window of N days can only ever contain a span of N-1, so that is the denominator;
  // getting this wrong is how `measured` mode becomes silently unreachable.
  const cSpan = clamp01(
    (measurement.spanDays - MIN_SPAN_DAYS) / (TARGET_WINDOW_DAYS - 1 - MIN_SPAN_DAYS),
  );
  const cCoverage = clamp01((measurement.coverage - MIN_COVERAGE) / 0.3);
  // Density of weigh-ins, not just their span: a slope fitted through three points
  // across four weeks has a standard error far too wide to act on.
  const cDensity = clamp01((measurement.weighIns / measurement.spanDays - 0.25) / 0.35);
  const confidence = cSpan * cCoverage * cDensity;

  const kcal = confidence * measurement.kcal + (1 - confidence) * formula;
  const mode: TdeeMode = confidence >= 0.95 ? 'measured' : confidence > 0 ? 'blended' : 'formula';

  if (mode === 'measured') {
    notes.push(`Measured from your last ${measurement.spanDays} days.`);
  } else if (mode === 'blended') {
    notes.push(
      `Part measured, part estimated — ${measurement.spanDays} days in, ` +
        `${Math.round(measurement.coverage * 100)}% logged.`,
    );
  }

  return { kcal, mode, confidence, measured: measurement.kcal, formula, notes };
}

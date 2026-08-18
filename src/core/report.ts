/**
 * The daily report — the single entry point the app layer calls.
 *
 * Pure: (Profile, LogBook, asOfDate) -> DailyReport. No I/O, no clock, no cache.
 */

import { dayNumber } from './dates';
import { dailyIntake, resolveTdee, type TdeeResult } from './tdee';
import { intakeTarget, waterTargetMl, bmi, type IntakeTarget } from './targets';
import { trendAt, trendDelta, weightTrend, type TrendPoint } from './weightTrend';
import type { ISODate, LogBook, Profile } from './types';

export interface DailyReport {
  date: ISODate;

  weight: {
    rawToday: number | null;
    trend: number | null;
    delta7d: number | null;
    delta30d: number | null;
    bmi: number | null;
  };

  energy: {
    tdee: TdeeResult;
    target: IntakeTarget;
    consumed: number;
    /** Null when no target may be shown. */
    remaining: number | null;
  };

  water: {
    consumedMl: number;
    targetMl: number | null;
  };

  /** Everything the UI should surface as caveats, already in plain language. */
  notices: string[];
}

export function dailyReport(
  profile: Profile,
  log: LogBook,
  asOfDate: ISODate,
  /** Injected rather than read from a clock, so reports are reproducible. */
  currentYear: number,
): DailyReport {
  const asOfDay = dayNumber(asOfDate);
  const ageYears = currentYear - profile.birthYear;

  const trend: TrendPoint[] = weightTrend(log.weighIns);
  const at = trendAt(trend, asOfDay);
  const rawToday = log.weighIns.find((w) => w.date === asOfDate)?.kg ?? null;

  const intake = dailyIntake(log.food);
  const consumed = intake.get(asOfDay) ?? 0;
  const consumedMl = log.water
    .filter((w) => w.date === asOfDate)
    .reduce((s, w) => s + w.ml, 0);

  const notices: string[] = [];

  // Without any weight history there is nothing to anchor either the formula or the
  // measurement to, so the report is deliberately empty rather than guessed at.
  if (!at) {
    return {
      date: asOfDate,
      weight: { rawToday, trend: null, delta7d: null, delta30d: null, bmi: null },
      energy: {
        tdee: { kcal: 0, mode: 'formula', confidence: 0, measured: null, formula: 0, notes: [] },
        target: { kcal: null, appliedDeficit: 0, warnings: [], clamped: false },
        consumed,
        remaining: null,
      },
      water: { consumedMl, targetMl: null },
      notices: ['Log your weight to get started.'],
    };
  }

  const tdee = resolveTdee(profile, trend, intake, asOfDay, at.trend, ageYears);
  const target = intakeTarget(profile, tdee.kcal, at.trend, ageYears);

  notices.push(...tdee.notes, ...target.warnings);

  const delta7d = trendDelta(trend, asOfDay, 7);
  // A large, fast early drop is water and glycogen, not fat. Saying so pre-empts both
  // the false confidence and the crash that follows when it stops.
  if (delta7d !== null && delta7d < -1.2) {
    notices.push(
      'Fast early drops are mostly water, not fat. Expect this to level off.',
    );
  }

  return {
    date: asOfDate,
    weight: {
      rawToday,
      trend: at.trend,
      delta7d,
      delta30d: trendDelta(trend, asOfDay, 30),
      bmi: bmi(at.trend, profile.heightCm),
    },
    energy: {
      tdee,
      target,
      consumed,
      remaining: target.kcal === null ? null : target.kcal - consumed,
    },
    water: { consumedMl, targetMl: waterTargetMl(at.trend) },
    notices,
  };
}

/**
 * Weight trend.
 *
 * Raw daily weight swings ±1–2 kg on water, glycogen and gut content alone. Anything
 * that differences raw weigh-ins — including the TDEE measurement — is differencing
 * mostly noise. So the trend line is the primary number everywhere in the app, and
 * raw weight is shown only as scattered dots behind it.
 */

import { dayNumber } from './dates';
import type { ISODate, WeighIn } from './types';

/** ~7-day effective window. */
export const TREND_ALPHA = 0.25;

export interface TrendPoint {
  date: ISODate;
  day: number;
  raw: number;
  trend: number;
}

/**
 * Time-aware EMA: the smoothing factor is compounded across the gap since the last
 * weigh-in, so a user who skips four days does not get a trend line lagging four days
 * behind reality. With no gaps this reduces exactly to a standard EMA.
 */
export function weightTrend(weighIns: WeighIn[], alpha = TREND_ALPHA): TrendPoint[] {
  const sorted = [...weighIns].sort((a, b) => dayNumber(a.date) - dayNumber(b.date));
  const out: TrendPoint[] = [];
  let trend: number | null = null;
  let prevDay = 0;

  for (const w of sorted) {
    const day = dayNumber(w.date);
    if (trend === null) {
      trend = w.kg;
    } else {
      const gap = Math.max(1, day - prevDay);
      const alphaEff = 1 - Math.pow(1 - alpha, gap);
      trend = trend + alphaEff * (w.kg - trend);
    }
    prevDay = day;
    out.push({ date: w.date, day, raw: w.kg, trend });
  }
  return out;
}

/**
 * Trend value as of `day`, using the most recent point at or before it.
 *
 * Returns null when the newest available point is more than `maxStaleDays` old —
 * an eleven-day-old weight is not evidence about today, and silently reusing it
 * would let the TDEE measurement invent a deficit out of a logging gap.
 */
export function trendAt(
  points: TrendPoint[],
  day: number,
  maxStaleDays = 7,
): TrendPoint | null {
  let best: TrendPoint | null = null;
  for (const p of points) {
    if (p.day <= day && (best === null || p.day > best.day)) best = p;
  }
  if (best === null || day - best.day > maxStaleDays) return null;
  return best;
}

/** Trend change over the trailing `days`, or null if there is not enough history. */
export function trendDelta(points: TrendPoint[], asOfDay: number, days: number): number | null {
  const end = trendAt(points, asOfDay);
  const start = trendAt(points, asOfDay - days);
  if (!end || !start || end.day === start.day) return null;
  return end.trend - start.trend;
}

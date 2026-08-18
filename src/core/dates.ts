/**
 * Calendar arithmetic on `YYYY-MM-DD` strings.
 *
 * Parsed manually rather than through Date, so that a user in IST and a test running
 * in UTC agree on what day it is. Every date in the system is a local calendar date;
 * there are no timestamps anywhere in the engine.
 */

import type { ISODate } from './types';

const MS_PER_DAY = 86_400_000;

/** Days since 1970-01-01, treating the input as a bare calendar date. */
export function dayNumber(date: ISODate): number {
  const y = Number(date.slice(0, 4));
  const m = Number(date.slice(5, 7));
  const d = Number(date.slice(8, 10));
  if (!Number.isFinite(y) || !Number.isFinite(m) || !Number.isFinite(d)) {
    throw new Error(`bad ISODate: ${date}`);
  }
  return Math.round(Date.UTC(y, m - 1, d) / MS_PER_DAY);
}

export function fromDayNumber(day: number): ISODate {
  const dt = new Date(day * MS_PER_DAY);
  const y = dt.getUTCFullYear();
  const m = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const d = String(dt.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export const addDays = (date: ISODate, n: number): ISODate =>
  fromDayNumber(dayNumber(date) + n);

export const daysBetween = (from: ISODate, to: ISODate): number =>
  dayNumber(to) - dayNumber(from);

/**
 * The single call into the engine.
 *
 * `dailyReport` is a pure function of (Profile, LogBook, date, year) — no clock, no I/O
 * — which is why the same code the simulation proves runs here untouched. The app's job
 * is only to shape its state into a LogBook.
 */

import { useMemo } from 'react';
import { dailyReport, type DailyReport } from '@core/report';
import { weightTrend, type TrendPoint } from '@core/weightTrend';
import type { LogBook } from '@core/types';
import { totalWaterMl } from '../store/actions';
import { useStore } from '../store/store';
import type { AppState } from '../store/state';
import { todayISO } from '../domain/time';

export function toLogBook(s: AppState, today: string): LogBook {
  return {
    weighIns: s.log.weighIns,
    food: s.entries.map((e) => ({ date: e.date, kcal: e.kcal, label: e.name })),
    water: [{ date: today, ml: totalWaterMl(s) }],
  };
}

export interface Derived {
  report: DailyReport;
  trend: TrendPoint[];
  weighInCount: number;
  /** Days between the first and most recent weigh-in — what the engine actually spans. */
  spanDays: number;
}

export function useReport(): Derived {
  const s = useStore((x) => x);
  const today = todayISO();

  return useMemo(() => {
    const log = toLogBook(s, today);
    const report = dailyReport(s.profile, log, today, new Date().getFullYear());
    const trend = weightTrend(log.weighIns);
    const first = trend[0];
    const last = trend[trend.length - 1];
    return {
      report,
      trend,
      weighInCount: trend.length,
      spanDays: first && last ? last.day - first.day : 0,
    };
  }, [s, today]);
}

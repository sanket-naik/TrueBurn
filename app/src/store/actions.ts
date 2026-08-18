/**
 * Every mutation the UI can perform, including the two-way sync between Today and
 * Routines (REQUIREMENTS §7.4). Pure functions over state — no React, no I/O — so the
 * sync rules are testable without rendering anything.
 */

import { dayNumber, fromDayNumber } from '@core/dates';
import type { Food, Meal } from '../domain/foods';
import { mealFor } from '../domain/foods';
import {
  TEMPLATES,
  rollover,
  waterFromRoutines,
  type Routine,
  type RoutineType,
} from '../domain/routines';
import { convertWater, satisfyFood } from '../domain/sync';
import { mins, todayISO, minutesNow } from '../domain/time';
import { set } from './store';
import type { AppState, Entry } from './state';

const uid = (): string => `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

export const totalWaterMl = (s: AppState): number =>
  s.water.manualMl + waterFromRoutines(s.routines);

export const consumedKcal = (s: AppState, date: string): number =>
  s.entries.filter((e) => e.date === date).reduce((a, e) => a + e.kcal, 0);

// ---------------------------------------------------------------- day rollover

/** Move `done` into `doneYesterday` and reset the day's water when the date changes. */
export function rolloverDay(): void {
  const today = todayISO();
  set((s) => {
    if (s.water.date === today && s.routines.every((r) => r.lastRollover === today)) return s;
    const yesterday = fromDayNumber(dayNumber(today) - 1);
    return {
      ...s,
      routines: s.routines.map((r) => rollover(r, today, yesterday)),
      water: s.water.date === today ? s.water : { date: today, manualMl: 0 },
    };
  });
}

// ---------------------------------------------------------------- water


export function addWater(ml: number, paused: boolean): void {
  const now = new Date();
  set((s) => {
    const split = convertWater(
      s.routines,
      s.water.manualMl + ml,
      minutesNow(now),
      now.getDay(),
      paused,
    );
    return { ...s, routines: split.routines, water: { ...s.water, manualMl: split.manualMl } };
  });
}

// ---------------------------------------------------------------- food


export function addEntry(food: Food, qty: number, paused: boolean): void {
  const now = new Date();
  const nowMin = minutesNow(now);
  const entry: Entry = {
    id: uid(),
    date: todayISO(now),
    name: food.n,
    unit: food.u,
    qty,
    kcal: Math.round(food.k * qty),
    meal: mealFor(nowMin),
  };
  set((s) => ({
    ...s,
    entries: [...s.entries, entry],
    recents: [food.n, ...s.recents.filter((n) => n !== food.n)].slice(0, 6),
    routines: satisfyFood(s.routines, nowMin, now.getDay(), paused),
  }));
}

export function addCustomFood(name: string, kcal: number, paused: boolean): void {
  const food: Food = { n: name.trim(), u: '1 serving', k: kcal };
  set((s) => ({ ...s, customFoods: [food, ...s.customFoods] }));
  addEntry(food, 1, paused);
}

export function removeEntry(id: string): void {
  set((s) => ({ ...s, entries: s.entries.filter((e) => e.id !== id) }));
}

export function copyYesterday(paused: boolean): void {
  const now = new Date();
  const today = todayISO(now);
  const yesterday = fromDayNumber(dayNumber(today) - 1);
  set((s) => {
    const prior = s.entries.filter((e) => e.date === yesterday);
    if (!prior.length) return s;
    const copies = prior.map((e) => ({ ...e, id: uid(), date: today }));
    return {
      ...s,
      entries: [...s.entries, ...copies],
      routines: satisfyFood(s.routines, minutesNow(now), now.getDay(), paused),
    };
  });
}

// ---------------------------------------------------------------- weight

/** One raw weigh-in per day; logging again replaces it rather than double-counting. */
export function logWeight(kg: number): void {
  const date = todayISO();
  set((s) => ({
    ...s,
    profileSet: true,
    log: {
      ...s.log,
      weighIns: [...s.log.weighIns.filter((w) => w.date !== date), { date, kg }].sort((a, b) =>
        a.date < b.date ? -1 : 1,
      ),
    },
  }));
}

// ---------------------------------------------------------------- routines

export function tickReminder(id: string, time: string, paused: boolean): void {
  const now = new Date();
  set((s) => {
    const next = {
      ...s,
      routines: s.routines.map((r) =>
        r.id === id && !r.done.includes(time) ? { ...r, done: [...r.done, time].sort() } : r,
      ),
    };
    // Ticking a water reminder is already accounted for by `waterFromRoutines`; nothing
    // else to do. Gym and custom deliberately touch nothing but their own progress.
    return next;
  });
  void now;
}

export function untickReminder(id: string, time: string): void {
  set((s) => ({
    ...s,
    routines: s.routines.map((r) =>
      r.id === id ? { ...r, done: r.done.filter((t) => t !== time) } : r,
    ),
  }));
}

export function upsertRoutine(r: Routine): void {
  set((s) => ({
    ...s,
    routines: s.routines.some((x) => x.id === r.id)
      ? s.routines.map((x) => (x.id === r.id ? r : x))
      : [...s.routines, r],
  }));
}

export function deleteRoutine(id: string): void {
  set((s) => ({ ...s, routines: s.routines.filter((r) => r.id !== id) }));
}

export function toggleRoutine(id: string): void {
  set((s) => ({
    ...s,
    routines: s.routines.map((r) => (r.id === id ? { ...r, active: !r.active } : r)),
  }));
}

export function newRoutine(type: RoutineType): Routine {
  const t = TEMPLATES[type];
  return {
    id: uid(),
    type,
    name: t.name,
    message: t.message,
    times: [...t.times],
    days: [...t.days],
    amountMl: t.amountMl,
    totalDays: 30,
    elapsed: 0,
    active: true,
    done: [],
    doneYesterday: [],
    lastRollover: todayISO(),
  };
}

// ---------------------------------------------------------------- settings

export function patchSettings(patch: Partial<AppState['settings']>): void {
  set((s) => ({ ...s, settings: { ...s.settings, ...patch } }));
}

export function patchProfile(patch: Partial<AppState['profile']>): void {
  set((s) => ({ ...s, profile: { ...s.profile, ...patch }, profileSet: true }));
}

export type { Meal };

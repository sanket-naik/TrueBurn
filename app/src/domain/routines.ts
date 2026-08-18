/**
 * Routines — reminders the user creates and owns.
 *
 * Deliberately *outside* `src/core/`. Core is the energy engine; a routine is a
 * commitment tracker. Keeping them in separate modules is what structurally guarantees
 * the rule in REQUIREMENTS §7.2: a gym tick moves a progress bar and can never reach the
 * TDEE arithmetic, because this module has no way to write into a LogBook's food.
 */

import { mins, ampm, DOW_SHORT } from './time';

export type RoutineType = 'water' | 'food' | 'gym' | 'custom';

export interface Routine {
  id: string;
  type: RoutineType;
  name: string;
  message: string;
  /** Sorted `HH:MM` list. There is no interval builder — see §7.2. */
  times: string[];
  /** 0 = Sunday. */
  days: number[];
  /** Water only: millilitres logged per completion. */
  amountMl: number;
  totalDays: number;
  elapsed: number;
  active: boolean;
  /** Times ticked today, and yesterday. Completion is per reminder, not per day (§7.3). */
  done: string[];
  doneYesterday: string[];
  /** ISO date the `done`/`doneYesterday` pair was last rolled over. */
  lastRollover: string;
}

export interface Template {
  label: string;
  name: string;
  message: string;
  times: string[];
  days: number[];
  amountMl: number;
}

const EVERY_DAY = [0, 1, 2, 3, 4, 5, 6];

/**
 * Ready-made schedules. Picking a type loads one whole, which is what makes a working
 * water routine two taps. Water stops at 7 pm rather than 9 pm: six reminders instead of
 * seven keeps the default under the density warning and off bedtime.
 */
export const TEMPLATES: Record<RoutineType, Template> = {
  water: {
    label: 'Water',
    name: 'Drink water',
    message: 'Time for a glass.',
    times: ['09:00', '11:00', '13:00', '15:00', '17:00', '19:00'],
    days: EVERY_DAY,
    amountMl: 500,
  },
  food: {
    label: 'Food',
    name: 'Log your meals',
    message: 'Log what you ate. Takes 20 seconds.',
    times: ['08:30', '13:00', '17:00', '20:30'],
    days: EVERY_DAY,
    amountMl: 0,
  },
  gym: {
    label: 'Gym',
    name: 'Gym session',
    message: 'Session time.',
    times: ['18:30'],
    days: [1, 3, 5],
    amountMl: 0,
  },
  custom: {
    label: 'Custom',
    name: '',
    message: '',
    times: ['09:00'],
    days: EVERY_DAY,
    amountMl: 0,
  },
};

export const dueOn = (r: Routine, dow: number): boolean => r.days.includes(dow);

export const perDay = (r: Routine): number => r.times.length;
export const perWeek = (r: Routine): number => r.times.length * r.days.length;

export function dayText(r: Routine): string {
  if (r.days.length === 7) return 'every day';
  const weekday = r.days.length === 5 && !r.days.includes(0) && !r.days.includes(6);
  if (weekday) return 'weekdays';
  if (r.days.length === 2 && r.days.includes(0) && r.days.includes(6)) return 'weekends';
  return r.days.map((d) => DOW_SHORT[d]).join(' ');
}

export function whenText(r: Routine): string {
  const first = r.times[0];
  const last = r.times[r.times.length - 1];
  if (!first || !last) return dayText(r);
  if (r.times.length === 1) return `${ampm(first)} · ${dayText(r)}`;
  return `${r.times.length} times a day · ${ampm(first)}–${ampm(last)} · ${dayText(r)}`;
}

/** Times due today that have passed without a tick. */
export function missedTimes(r: Routine, dow: number, nowMin: number, paused: boolean): string[] {
  if (!r.active || paused || !dueOn(r, dow)) return [];
  return r.times.filter((t) => mins(t) < nowMin && !r.done.includes(t));
}

/** The reminder a "tick" button should target: the oldest lapsed one, else the next up. */
export function nextTime(r: Routine, nowMin: number): string | null {
  const pending = r.times.filter((t) => !r.done.includes(t));
  if (!pending.length) return null;
  const lapsed = pending.filter((t) => mins(t) < nowMin);
  return (lapsed.length ? lapsed[0] : pending[0]) ?? null;
}

/** Water contributed by ticked reminders. Derived, so it can never drift from the ticks. */
export const waterFromRoutines = (rs: Routine[]): number =>
  rs.reduce((s, r) => s + (r.type === 'water' && r.amountMl ? r.done.length * r.amountMl : 0), 0);

/** Roll `done` into `doneYesterday` when the calendar date changes. */
export function rollover(r: Routine, today: string, yesterday: string): Routine {
  if (r.lastRollover === today) return r;
  const carried = r.lastRollover === yesterday ? r.done : [];
  return { ...r, doneYesterday: carried, done: [], lastRollover: today, elapsed: r.elapsed + 1 };
}

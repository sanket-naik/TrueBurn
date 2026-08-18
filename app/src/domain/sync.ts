/**
 * The two-way sync rules between Today and Routines (REQUIREMENTS §7.4).
 *
 * Pure functions over plain data — no store, no React — so the rules that keep the two
 * screens from disagreeing can be proven headlessly, the same way the energy engine is.
 */

import { dueOn, type Routine } from './routines';
import { mins } from './time';

export interface WaterSplit {
  routines: Routine[];
  /** Millilitres still unattributed to any reminder. */
  manualMl: number;
}

/**
 * Convert accumulated unattributed water into reminder ticks.
 *
 * Works on the running pool, not on a single tap. With a +100 ml button, five taps make
 * a 500 ml bottle and must satisfy a 500 ml reminder exactly as one +500 tap does —
 * otherwise the timeline shows a miss for water the user demonstrably drank.
 *
 * Invariant: a conversion moves `amountMl` out of the pool and adds one tick worth
 * `amountMl`, so `manualMl + ticks × amountMl` is unchanged by this function.
 */
export function convertWater(
  routines: Routine[],
  manualMl: number,
  nowMin: number,
  dow: number,
  paused: boolean,
): WaterSplit {
  if (paused) return { routines, manualMl };
  let pool = manualMl;

  const next = routines.map((r) => {
    if (r.type !== 'water' || !r.active || !r.amountMl || !dueOn(r, dow)) return r;
    const done = [...r.done];
    for (const t of r.times) {
      if (pool < r.amountMl) break;
      // Never reach forward: a reminder set for later today is not satisfied by drinking
      // now, because the user has not got there yet.
      if (mins(t) > nowMin || done.includes(t)) continue;
      done.push(t);
      pool -= r.amountMl;
    }
    return done.length === r.done.length ? r : { ...r, done: done.sort() };
  });

  return { routines: next, manualMl: pool };
}

/**
 * A food routine is a reminder *to log*, so the act of logging satisfies it.
 *
 * Without this, someone who logs every meal from the Today screen sees a wall of missed
 * reminders and reasonably concludes the app is broken. Ticks the most recent reminder
 * already due — never a future one, which the user has not reached yet.
 */
export function satisfyFood(
  routines: Routine[],
  nowMin: number,
  dow: number,
  paused: boolean,
): Routine[] {
  if (paused) return routines;
  return routines.map((r) => {
    if (r.type !== 'food' || !r.active || !dueOn(r, dow)) return r;
    const due = r.times.filter((t) => mins(t) <= nowMin && !r.done.includes(t));
    const last = due[due.length - 1];
    return last ? { ...r, done: [...r.done, last].sort() } : r;
  });
}

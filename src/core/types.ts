/**
 * Core domain types.
 *
 * Nothing in src/core may import a platform API — no fetch, no fs, no React Native,
 * no Date.now(). The engine is a pure function of (Profile, LogBook, asOfDate).
 * That is what lets the whole thing be proven headlessly by src/sim.
 */

/** Local calendar date, `YYYY-MM-DD`. */
export type ISODate = string;

/**
 * Which Mifflin–St Jeor constant to use for the cold-start estimate.
 *
 * Chosen by the user directly rather than inferred from a gender field: the formula
 * is a population regression with two published variants, and asking which one fits
 * is both more honest and less presumptuous than deriving it.
 */
export type FormulaVariant = 'mifflin-male' | 'mifflin-female';

/** Cold-start only. Discarded once measurement takes over. */
export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active';

export type Goal =
  | { kind: 'lose'; kgPerWeek: number }
  | { kind: 'maintain' }
  | { kind: 'gain'; kgPerWeek: number };

export interface Profile {
  heightCm: number;
  birthYear: number;
  formulaVariant: FormulaVariant;
  /** Only consulted while confidence < 1. */
  activityLevel: ActivityLevel;
  goal: Goal;
}

export interface WeighIn {
  date: ISODate;
  kg: number;
}

export interface FoodEntry {
  date: ISODate;
  kcal: number;
  label: string;
}

export interface WaterEntry {
  date: ISODate;
  ml: number;
}

export interface LogBook {
  weighIns: WeighIn[];
  food: FoodEntry[];
  water: WaterEntry[];
}

export const emptyLogBook = (): LogBook => ({ weighIns: [], food: [], water: [] });

/** Energy density of body-mass change. Standard figure; assumes fat mass. */
export const KCAL_PER_KG = 7700;

export const clamp = (v: number, lo: number, hi: number): number =>
  v < lo ? lo : v > hi ? hi : v;

export const clamp01 = (v: number): number => clamp(v, 0, 1);

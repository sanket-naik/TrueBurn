/**
 * Turning expenditure into a daily target, with the safety rules enforced here rather
 * than in the UI so that no screen can route around them.
 */

import { KCAL_PER_KG, clamp, type FormulaVariant, type Goal, type Profile } from './types';

export const MAX_RATE_KG_PER_WEEK = 1.0;
export const BMI_FLOOR = 18.5;
export const MIN_AGE_FOR_TARGETS = 18;

const INTAKE_FLOOR: Record<FormulaVariant, number> = {
  'mifflin-male': 1500,
  'mifflin-female': 1200,
};

export interface IntakeTarget {
  /** kcal/day to aim for, after clamping. Null when no target may be shown. */
  kcal: number | null;
  /** Deficit actually applied, after clamping. Negative for a gain goal. */
  appliedDeficit: number;
  warnings: string[];
  /** True when a safety rule changed or withheld the number. */
  clamped: boolean;
}

export const bmi = (weightKg: number, heightCm: number): number =>
  weightKg / Math.pow(heightCm / 100, 2);

function rawDeficit(goal: Goal): number {
  switch (goal.kind) {
    case 'maintain':
      return 0;
    case 'lose':
      return (goal.kgPerWeek * KCAL_PER_KG) / 7;
    case 'gain':
      return -(goal.kgPerWeek * KCAL_PER_KG) / 7;
  }
}

export function intakeTarget(
  profile: Profile,
  tdeeKcal: number,
  weightKg: number,
  ageYears: number,
): IntakeTarget {
  const warnings: string[] = [];
  let clamped = false;

  if (ageYears < MIN_AGE_FOR_TARGETS) {
    return {
      kcal: null,
      appliedDeficit: 0,
      clamped: true,
      warnings: ['Calorie targets are only available to users 18 and over.'],
    };
  }

  const currentBmi = bmi(weightKg, profile.heightCm);
  if (currentBmi < BMI_FLOOR && profile.goal.kind === 'lose') {
    return {
      kcal: null,
      appliedDeficit: 0,
      clamped: true,
      warnings: [
        'Your BMI is already below the healthy range, so no weight-loss target is shown.' +
          ' Please talk to a doctor or dietitian before cutting intake further.',
      ],
    };
  }

  // Cap the requested rate before it ever reaches the arithmetic.
  let goal = profile.goal;
  if (goal.kind !== 'maintain' && goal.kgPerWeek > MAX_RATE_KG_PER_WEEK) {
    warnings.push(
      `Rate capped at ${MAX_RATE_KG_PER_WEEK} kg/week (you asked for ${goal.kgPerWeek}).`,
    );
    clamped = true;
    goal = { ...goal, kgPerWeek: MAX_RATE_KG_PER_WEEK };
  }

  const deficit = rawDeficit(goal);
  const floor = INTAKE_FLOOR[profile.formulaVariant];
  let kcal = tdeeKcal - deficit;

  if (kcal < floor) {
    warnings.push(
      `Target raised to the ${floor} kcal floor — your goal would have meant eating less` +
        ' than is safe to sustain. Expect slower progress than requested.',
    );
    clamped = true;
    kcal = floor;
  }

  return { kcal, appliedDeficit: tdeeKcal - kcal, warnings, clamped };
}

/**
 * Rule-of-thumb hydration target: ~35 ml per kg, bounded.
 *
 * Deliberately crude, and the UI must not dress it up as a clinical requirement —
 * real needs vary with climate, activity and diet far more than with body mass.
 */
export const waterTargetMl = (weightKg: number): number =>
  Math.round(clamp(35 * weightKg, 2000, 4000) / 50) * 50;

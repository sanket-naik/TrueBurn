/// Turning expenditure into a daily target, with the safety rules enforced here rather
/// than in the UI so that no screen can route around them.
library;

import 'dart:math' as math;

import 'types.dart';

const double maxRateKgPerWeek = 1.0;
const double bmiFloor = 18.5;
const int minAgeForTargets = 18;

const Map<FormulaVariant, double> _intakeFloor = {
  FormulaVariant.mifflinMale: 1500,
  FormulaVariant.mifflinFemale: 1200,
};

class IntakeTarget {
  /// kcal/day to aim for, after clamping. Null when no target may be shown.
  final double? kcal;

  /// Deficit actually applied, after clamping. Negative for a gain goal.
  final double appliedDeficit;
  final List<String> warnings;

  /// True when a safety rule changed or withheld the number.
  final bool clamped;

  const IntakeTarget({
    required this.kcal,
    required this.appliedDeficit,
    required this.warnings,
    required this.clamped,
  });
}

double bmi(double weightKg, double heightCm) => weightKg / math.pow(heightCm / 100, 2);

double _rawDeficit(Goal goal) => switch (goal) {
      MaintainGoal() => 0,
      LoseGoal(kgPerWeek: final r) => r * kcalPerKg / 7,
      GainGoal(kgPerWeek: final r) => -(r * kcalPerKg / 7),
    };

IntakeTarget intakeTarget(Profile profile, double tdeeKcal, double weightKg, int ageYears) {
  final warnings = <String>[];
  var clamped = false;

  if (ageYears < minAgeForTargets) {
    return const IntakeTarget(
      kcal: null,
      appliedDeficit: 0,
      clamped: true,
      warnings: ['Calorie targets are only available to users 18 and over.'],
    );
  }

  final currentBmi = bmi(weightKg, profile.heightCm);
  if (currentBmi < bmiFloor && profile.goal is LoseGoal) {
    return const IntakeTarget(
      kcal: null,
      appliedDeficit: 0,
      clamped: true,
      warnings: [
        'Your BMI is already below the healthy range, so no weight-loss target is shown.'
            ' Please talk to a doctor or dietitian before cutting intake further.'
      ],
    );
  }

  // Cap the requested rate before it ever reaches the arithmetic.
  var goal = profile.goal;
  if (goal is LoseGoal && goal.kgPerWeek > maxRateKgPerWeek) {
    warnings.add('Rate capped at $maxRateKgPerWeek kg/week (you asked for ${goal.kgPerWeek}).');
    clamped = true;
    goal = const LoseGoal(maxRateKgPerWeek);
  } else if (goal is GainGoal && goal.kgPerWeek > maxRateKgPerWeek) {
    warnings.add('Rate capped at $maxRateKgPerWeek kg/week (you asked for ${goal.kgPerWeek}).');
    clamped = true;
    goal = const GainGoal(maxRateKgPerWeek);
  }

  final deficit = _rawDeficit(goal);
  final floor = _intakeFloor[profile.formulaVariant]!;
  var kcal = tdeeKcal - deficit;

  if (kcal < floor) {
    warnings.add('Target raised to the ${floor.round()} kcal floor — your goal would have '
        'meant eating less than is safe to sustain. Expect slower progress than requested.');
    clamped = true;
    kcal = floor;
  }

  return IntakeTarget(
    kcal: kcal,
    appliedDeficit: tdeeKcal - kcal,
    warnings: warnings,
    clamped: clamped,
  );
}

/// Rule-of-thumb hydration target: ~35 ml per kg, bounded.
///
/// Deliberately crude, and the UI must not dress it up as a clinical requirement — real
/// needs vary with climate, activity and diet far more than with body mass.
int waterTargetMl(double weightKg) =>
    (clampD(35 * weightKg, 2000, 4000) / 50).round() * 50;

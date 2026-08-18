/// Synthetic users with a *known* true TDEE and a closed behavioural feedback loop.
///
/// A faithful port of `src/sim/simulate.ts`. The order of `rand()` calls is part of the
/// contract: change it and the seeded stream diverges, which would look like an engine
/// difference when it is only a sequencing one.
library;

import 'dart:math' as math;

import 'package:trueburn/core/dates.dart';
import 'package:trueburn/core/report.dart';
import 'package:trueburn/core/targets.dart';
import 'package:trueburn/core/tdee.dart';
import 'package:trueburn/core/types.dart';
import 'rng.dart';

const String startDate = '2026-01-01';
const int simYear = 2026;

class PersonSpec {
  final String name;

  /// Ground truth the engine is trying to discover.
  final double trueTdee;
  final double tdeeNoiseSd;

  /// Systematic logging factor. 0.75 = habitually logs 25% low.
  final double logFactor;

  /// Logging factor at the end of the run, interpolated linearly from [logFactor].
  final double? logFactorEnd;

  /// Per-day random error in the logging factor — guessing at home-cooked portions.
  final double logNoiseSd;
  final double foodLogProb;
  final double weighInProb;
  final double startWeightKg;
  final double scaleNoiseSd;

  const PersonSpec({
    required this.name,
    required this.trueTdee,
    required this.logFactor,
    required this.foodLogProb,
    this.logFactorEnd,
    this.logNoiseSd = 0,
    this.tdeeNoiseSd = 120,
    this.weighInProb = 0.85,
    this.startWeightKg = 82,
    this.scaleNoiseSd = 0.45,
  });
}

enum Coach { adaptive, formulaOnly }

class DaySnapshot {
  final int day;
  final double trueWeight;
  final double trueTdeeToday;
  final double trueIntake;
  final double? target;
  final bool clamped;
  final double tdeeShown;
  final double? tdeeMeasured;
  final TdeeMode mode;
  final double confidence;

  const DaySnapshot({
    required this.day,
    required this.trueWeight,
    required this.trueTdeeToday,
    required this.trueIntake,
    required this.target,
    required this.clamped,
    required this.tdeeShown,
    required this.tdeeMeasured,
    required this.mode,
    required this.confidence,
  });
}

/// Expenditure falls as mass falls: roughly 10 kcal/kg of BMR through the activity
/// multiplier. Without it the engine chases a stationary target, which is the one case
/// real weight loss never is.
const double _lossSensitivity = 10 * 1.375;

double _trueTdeeAt(PersonSpec spec, double weightKg) =>
    spec.trueTdee - (spec.startWeightKg - weightKg) * _lossSensitivity;

double _logFactorAt(PersonSpec spec, int day, int totalDays, double Function() rand) {
  final end = spec.logFactorEnd ?? spec.logFactor;
  final drifted =
      spec.logFactor + (end - spec.logFactor) * (day / math.max(1, totalDays - 1));
  final noisy = drifted * (1 + gaussian(rand) * spec.logNoiseSd);
  return math.min(1.4, math.max(0.4, noisy));
}

class SimResult {
  final PersonSpec spec;
  final Coach coach;
  final List<DaySnapshot> days;
  const SimResult(this.spec, this.coach, this.days);
}

SimResult simulate(Profile profile, PersonSpec spec, Coach coach, int totalDays, int seed) {
  final rand = mulberry32(seed);
  final weighIns = <WeighIn>[];
  final food = <FoodEntry>[];
  final water = <WaterEntry>[];
  final days = <DaySnapshot>[];

  var trueWeight = spec.startWeightKg;
  final ageYears = simYear - profile.birthYear;

  for (var day = 0; day < totalDays; day++) {
    final date = addDays(startDate, day);

    // Morning weigh-in, before eating. Note the short-circuit: on day 0 `rand()` is not
    // called at all, and replicating that is what keeps the stream aligned.
    if (day == 0 || rand() < spec.weighInProb) {
      final noise =
          gaussian(rand) * spec.scaleNoiseSd + 0.5 * math.sin((day * 2 * math.pi) / 9);
      weighIns.add(WeighIn(date, ((trueWeight + noise) * 10).round() / 10));
    }

    double? target;
    bool clamped;
    double tdeeShown;
    double? tdeeMeasured;
    var mode = TdeeMode.formula;
    var confidence = 0.0;

    if (coach == Coach.adaptive) {
      final log = LogBook(weighIns: weighIns, food: food, water: water);
      final report = dailyReport(profile, log, date, simYear);
      target = report.energy.target.kcal;
      clamped = report.energy.target.clamped;
      tdeeShown = report.energy.tdee.kcal;
      tdeeMeasured = report.energy.tdee.measured;
      mode = report.energy.tdee.mode;
      confidence = report.energy.tdee.confidence;
    } else {
      // Control: a population formula and a self-declared activity level, forever.
      tdeeShown = formulaTdee(profile, trueWeight, ageYears);
      final t = intakeTarget(profile, tdeeShown, trueWeight, ageYears);
      target = t.kcal;
      clamped = t.clamped;
    }

    final factorToday = _logFactorAt(spec, day, totalDays, rand);
    final aim = target ?? _trueTdeeAt(spec, trueWeight);
    final trueIntake =
        math.max(800.0, (aim / factorToday) * (1 + gaussian(rand) * 0.08));

    if (rand() < spec.foodLogProb) {
      food.add(FoodEntry(date, (trueIntake * factorToday).roundToDouble(), 'day total'));
    }
    water.add(WaterEntry(date, 2000 + (rand() * 1200).round()));

    final trueTdeeToday = _trueTdeeAt(spec, trueWeight);

    days.add(DaySnapshot(
      day: day,
      trueWeight: trueWeight,
      trueTdeeToday: trueTdeeToday,
      trueIntake: trueIntake,
      target: target,
      clamped: clamped,
      tdeeShown: tdeeShown,
      tdeeMeasured: tdeeMeasured,
      mode: mode,
      confidence: confidence,
    ));

    trueWeight +=
        (trueIntake - (trueTdeeToday + gaussian(rand) * spec.tdeeNoiseSd)) / kcalPerKg;
  }

  return SimResult(spec, coach, days);
}

/// Observed rate of change of true mass over the trailing [window] days, in kg/week.
double? actualRateKgPerWeek(List<DaySnapshot> days, {int window = 30}) {
  if (days.length < window + 1) return null;
  final end = days[days.length - 1];
  final start = days[days.length - 1 - window];
  return ((end.trueWeight - start.trueWeight) / window) * 7;
}

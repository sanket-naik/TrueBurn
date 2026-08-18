/// The daily report — the single entry point the app layer calls.
///
/// Pure: (Profile, LogBook, asOfDate) -> DailyReport. No I/O, no clock, no cache.
library;

import 'dates.dart';
import 'targets.dart';
import 'tdee.dart';
import 'types.dart';
import 'weight_trend.dart';

class WeightBlock {
  final double? rawToday;
  final double? trend;
  final double? delta7d;
  final double? delta30d;
  final double? bmi;
  const WeightBlock({this.rawToday, this.trend, this.delta7d, this.delta30d, this.bmi});
}

class EnergyBlock {
  final TdeeResult tdee;
  final IntakeTarget target;
  final double consumed;

  /// Null when no target may be shown.
  final double? remaining;
  const EnergyBlock({
    required this.tdee,
    required this.target,
    required this.consumed,
    required this.remaining,
  });
}

class WaterBlock {
  final int consumedMl;
  final int? targetMl;
  const WaterBlock(this.consumedMl, this.targetMl);
}

class DailyReport {
  final ISODate date;
  final WeightBlock weight;
  final EnergyBlock energy;
  final WaterBlock water;

  /// Everything the UI should surface as caveats, already in plain language.
  final List<String> notices;

  const DailyReport({
    required this.date,
    required this.weight,
    required this.energy,
    required this.water,
    required this.notices,
  });
}

DailyReport dailyReport(
  Profile profile,
  LogBook log,
  ISODate asOfDate,
  /// Injected rather than read from a clock, so reports are reproducible.
  int currentYear,
) {
  final asOfDay = dayNumber(asOfDate);
  final ageYears = currentYear - profile.birthYear;

  final trend = weightTrend(log.weighIns);
  final at = trendAt(trend, asOfDay);

  double? rawToday;
  for (final w in log.weighIns) {
    if (w.date == asOfDate) rawToday = w.kg;
  }

  final intake = dailyIntake(log.food);
  final consumed = intake[asOfDay] ?? 0;
  var consumedMl = 0;
  for (final w in log.water) {
    if (w.date == asOfDate) consumedMl += w.ml;
  }

  final notices = <String>[];

  // Without any weight history there is nothing to anchor either the formula or the
  // measurement to, so the report is deliberately empty rather than guessed at.
  if (at == null) {
    return DailyReport(
      date: asOfDate,
      weight: WeightBlock(rawToday: rawToday),
      energy: EnergyBlock(
        tdee: const TdeeResult(
          kcal: 0,
          mode: TdeeMode.formula,
          confidence: 0,
          measured: null,
          formula: 0,
          notes: [],
        ),
        target: const IntakeTarget(kcal: null, appliedDeficit: 0, warnings: [], clamped: false),
        consumed: consumed,
        remaining: null,
      ),
      water: WaterBlock(consumedMl, null),
      notices: const ['Log your weight to get started.'],
    );
  }

  final tdee = resolveTdee(profile, trend, intake, asOfDay, at.trend, ageYears);
  final target = intakeTarget(profile, tdee.kcal, at.trend, ageYears);

  notices.addAll(tdee.notes);
  notices.addAll(target.warnings);

  final delta7d = trendDelta(trend, asOfDay, 7);
  // A large, fast early drop is water and glycogen, not fat. Saying so pre-empts both
  // the false confidence and the crash that follows when it stops.
  if (delta7d != null && delta7d < -1.2) {
    notices.add('Fast early drops are mostly water, not fat. Expect this to level off.');
  }

  return DailyReport(
    date: asOfDate,
    weight: WeightBlock(
      rawToday: rawToday,
      trend: at.trend,
      delta7d: delta7d,
      delta30d: trendDelta(trend, asOfDay, 30),
      bmi: bmi(at.trend, profile.heightCm),
    ),
    energy: EnergyBlock(
      tdee: tdee,
      target: target,
      consumed: consumed,
      remaining: target.kcal == null ? null : target.kcal! - consumed,
    ),
    water: WaterBlock(consumedMl, waterTargetMl(at.trend)),
    notices: notices,
  );
}

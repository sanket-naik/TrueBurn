/// Adaptive TDEE — the reason this app exists.
///
/// Every competitor asks the user to declare an activity level and then trusts a
/// population regression. Mifflin–St Jeor is ±10–15% off for any given individual,
/// and self-reported activity level is worse than that. Given a weight trend and an
/// intake log we can instead *measure* expenditure directly:
///
///     TDEE = averageIntake - (weightChangeKg * 7700) / days
///
/// The formula is kept only as a cold-start fallback, and blended out as the
/// measurement earns confidence.
library;

import 'dates.dart';
import 'types.dart';
import 'weight_trend.dart';

const int targetWindowDays = 28;
const int minSpanDays = 12;
const double minCoverage = 0.6;

const Map<ActivityLevel, double> _activityMultiplier = {
  ActivityLevel.sedentary: 1.2,
  ActivityLevel.light: 1.375,
  ActivityLevel.moderate: 1.55,
  ActivityLevel.active: 1.725,
};

/// Mifflin–St Jeor basal metabolic rate.
double mifflinBmr(FormulaVariant variant, double weightKg, double heightCm, int ageYears) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  return variant == FormulaVariant.mifflinMale ? base + 5 : base - 161;
}

double formulaTdee(Profile profile, double weightKg, int ageYears) {
  final bmr = mifflinBmr(profile.formulaVariant, weightKg, profile.heightCm, ageYears);
  return bmr * _activityMultiplier[profile.activityLevel]!;
}

/// kcal per calendar day, summed across entries. Keyed by day number.
Map<int, double> dailyIntake(List<FoodEntry> food) {
  final m = <int, double>{};
  for (final f in food) {
    final d = dayNumber(f.date);
    m[d] = (m[d] ?? 0) + f.kcal;
  }
  return m;
}

class Measurement {
  final double kcal;
  final int spanDays;
  final double coverage;
  final double avgIntake;
  final double deltaKg;
  final int loggedDays;

  /// Weigh-ins the slope was fitted through.
  final int weighIns;

  const Measurement({
    required this.kcal,
    required this.spanDays,
    required this.coverage,
    required this.avgIntake,
    required this.deltaKg,
    required this.loggedDays,
    required this.weighIns,
  });
}

/// Least-squares slope of weight against day, in kg/day.
///
/// Fitted through the *raw* weigh-ins, not the EMA. The EMA exists for display, where
/// its lag is a feature; as a slope estimator that lag is a bias, and regressing an
/// already-smoothed series also understates the true variance. OLS on the raw points
/// uses every observation, which is the whole reason it beats differencing two
/// endpoints — a single noisy weigh-in at either end no longer moves the answer much.
double? _weightSlope(List<TrendPoint> points) {
  final n = points.length;
  if (n < 3) return null;
  var sx = 0.0, sy = 0.0, sxy = 0.0, sxx = 0.0;
  for (final p in points) {
    sx += p.day;
    sy += p.raw;
    sxy += p.day * p.raw;
    sxx += p.day * p.day.toDouble();
  }
  final denom = n * sxx - sx * sx;
  if (denom == 0) return null;
  return (n * sxy - sx * sy) / denom;
}

class MeasureResult {
  final Measurement? measurement;
  final String? reason;
  const MeasureResult(this.measurement, [this.reason]);
}

/// Measure TDEE over the window ending at [asOfDay].
///
/// Anchored on actual weigh-ins rather than the nominal window edges, so the span is
/// always a real observed interval. Returns null when the data cannot support a
/// measurement — that is a normal state for the first three weeks, not an error.
MeasureResult measureTdee(
  List<TrendPoint> trend,
  Map<int, double> intake,
  int asOfDay, {
  int windowDays = targetWindowDays,
}) {
  final windowStart = asOfDay - windowDays + 1;

  final end = trendAt(trend, asOfDay);
  if (end == null) return const MeasureResult(null, 'no recent weigh-in');

  final inWindow = trend.where((p) => p.day >= windowStart && p.day <= end.day).toList();
  if (inWindow.length < 3) {
    return const MeasureResult(null, 'need at least three weigh-ins');
  }
  final start = inWindow.first;

  final spanDays = end.day - start.day;
  if (spanDays < minSpanDays) {
    return MeasureResult(null, 'span ${spanDays}d, need ${minSpanDays}d');
  }

  final slope = _weightSlope(inWindow);
  if (slope == null) return const MeasureResult(null, 'cannot fit a weight trend');

  // Intake over the observed interval. Weigh-ins are a morning protocol, so the weight
  // measured on end.day reflects eating through end.day - 1; the causally matching
  // intake window is [start.day, end.day - 1], which is exactly spanDays days.
  //
  // Days with no food log are excluded from the mean and then implicitly assumed to
  // equal it — the least-bad assumption available. People skip logging on heavy days,
  // so this biases low; see REQUIREMENTS §4.3 for why the feedback loop absorbs that.
  var sum = 0.0;
  var loggedDays = 0;
  for (var d = start.day; d < end.day; d++) {
    final kcal = intake[d];
    if (kcal != null && kcal > 0) {
      sum += kcal;
      loggedDays++;
    }
  }

  final coverage = loggedDays / spanDays;
  if (coverage < minCoverage) {
    return MeasureResult(null, 'only ${(coverage * 100).round()}% of days logged');
  }

  final avgIntake = sum / loggedDays;
  final deltaKg = slope * spanDays;
  final kcal = avgIntake - (deltaKg * kcalPerKg) / spanDays;

  return MeasureResult(Measurement(
    kcal: kcal,
    spanDays: spanDays,
    coverage: coverage,
    avgIntake: avgIntake,
    deltaKg: deltaKg,
    loggedDays: loggedDays,
    weighIns: inWindow.length,
  ));
}

enum TdeeMode { formula, blended, measured }

class TdeeResult {
  /// The number to show the user.
  final double kcal;
  final TdeeMode mode;

  /// 0..1. Drives the blend and the honesty of the UI label.
  final double confidence;
  final double? measured;
  final double formula;
  final List<String> notes;

  const TdeeResult({
    required this.kcal,
    required this.mode,
    required this.confidence,
    required this.measured,
    required this.formula,
    required this.notes,
  });
}

/// Blend measurement into formula as confidence accrues.
///
/// Confidence needs a long enough observed span, dense enough logging, and dense enough
/// weigh-ins; any one alone is not evidence. The product of the three means a user who
/// logs sporadically never fully leaves formula mode, which is the correct behaviour.
TdeeResult resolveTdee(
  Profile profile,
  List<TrendPoint> trend,
  Map<int, double> intake,
  int asOfDay,
  double currentWeightKg,
  int ageYears,
) {
  final formula = formulaTdee(profile, currentWeightKg, ageYears);
  final notes = <String>[];

  final res = measureTdee(trend, intake, asOfDay);
  final m = res.measurement;
  if (m == null) {
    if (res.reason != null) notes.add('Still estimating: ${res.reason}.');
    return TdeeResult(
      kcal: formula,
      mode: TdeeMode.formula,
      confidence: 0,
      measured: null,
      formula: formula,
      notes: notes,
    );
  }

  // A measurement outside physiological range is almost always a data error — a weight
  // typed in pounds, a 20,000 kcal fat-finger — not a genuinely unusual metabolism.
  // Reject rather than act on it.
  //
  // Anchored to **BMR, not the formula**. The formula carries the self-reported activity
  // multiplier (1.2 to 1.725), so anchoring there let a dropdown decide which real
  // measurements were believable: across the full simulation, declaring "Active" instead
  // of "Light" rejected 9.7% of measurements against 0.1%, on identical data, and dropped
  // the engine back to the very formula it exists to replace. The activity level is
  // supposed to stop mattering after three weeks; this was the one path that kept it
  // mattering forever.
  //
  // 0.85x-2.5x BMR spans bedbound to elite endurance. It is the band the old bounds
  // already produced at the default setting, so behaviour there is essentially unchanged
  // — what goes away is the dependence on a dropdown.
  final bmr =
      mifflinBmr(profile.formulaVariant, currentWeightKg, profile.heightCm, ageYears);
  if (m.kcal < bmr * 0.85 || m.kcal > bmr * 2.5) {
    notes.add('Measured expenditure looks implausible; check for a mistyped entry.');
    return TdeeResult(
      kcal: formula,
      mode: TdeeMode.formula,
      confidence: 0,
      measured: null,
      formula: formula,
      notes: notes,
    );
  }

  // A window of N days can only ever contain a span of N-1, so that is the denominator;
  // getting this wrong is how `measured` mode becomes silently unreachable.
  final cSpan = clamp01((m.spanDays - minSpanDays) / (targetWindowDays - 1 - minSpanDays));
  final cCoverage = clamp01((m.coverage - minCoverage) / 0.3);
  // Density of weigh-ins, not just their span: a slope fitted through three points
  // across four weeks has a standard error far too wide to act on.
  final cDensity = clamp01((m.weighIns / m.spanDays - 0.25) / 0.35);
  final confidence = cSpan * cCoverage * cDensity;

  final kcal = confidence * m.kcal + (1 - confidence) * formula;
  final mode = confidence >= 0.95
      ? TdeeMode.measured
      : confidence > 0
          ? TdeeMode.blended
          : TdeeMode.formula;

  if (mode == TdeeMode.measured) {
    notes.add('Measured from your last ${m.spanDays} days.');
  } else if (mode == TdeeMode.blended) {
    notes.add('Part measured, part estimated — ${m.spanDays} days in, '
        '${(m.coverage * 100).round()}% logged.');
  }

  return TdeeResult(
    kcal: kcal,
    mode: mode,
    confidence: confidence,
    measured: m.kcal,
    formula: formula,
    notes: notes,
  );
}

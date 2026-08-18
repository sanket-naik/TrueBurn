/// Past days, summarised. Pure — no Flutter, no clock, no I/O.
///
/// History is a *range summary over* a day list, not a bare list (§5.4). A list alone
/// would miss the point of a trend-based engine: the interesting figures are averages,
/// and the honest test of the whole product is predicted-vs-actual.
library;

import '../core/dates.dart';
import '../core/types.dart';
import '../core/weight_trend.dart';

/// One past day, as much of it as was actually recorded.
///
/// Every optional field means "not recorded", never zero. A day the user did not open
/// the app is not a day they drank nothing.
class DaySummary {
  final String date;
  final int dayNum;
  final int? kcal;
  final int? waterMl;
  final double? weightKg;
  final double? trendKg;

  /// Measured expenditure for that day, when the engine had enough to measure it.
  final double? burned;

  /// Reminder ticks, and how many were scheduled.
  final int ticksDone;
  final int ticksDue;

  const DaySummary({
    required this.date,
    required this.dayNum,
    this.kcal,
    this.waterMl,
    this.weightKg,
    this.trendKg,
    this.burned,
    this.ticksDone = 0,
    this.ticksDue = 0,
  });

  bool get isEmpty =>
      kcal == null && waterMl == null && weightKg == null && ticksDone == 0;

  int? get net => (kcal != null && burned != null) ? (kcal! - burned!).round() : null;
}

/// Averages over a window, plus the line that matters.
class RangeSummary {
  final int days;

  /// Days in the window that have any record at all — the honest denominator for the
  /// averages, and the number that says how much to trust them.
  final int logged;

  final double? avgEaten;
  final double? avgBurned;
  final double? avgWater;
  final int ticksDone;
  final int ticksDue;

  /// From the energy arithmetic: the weight change the deficits imply.
  final double? predictedKg;

  /// From the scale: the trend change over the same span.
  final double? actualKg;

  const RangeSummary({
    required this.days,
    required this.logged,
    this.avgEaten,
    this.avgBurned,
    this.avgWater,
    this.ticksDone = 0,
    this.ticksDue = 0,
    this.predictedKg,
    this.actualKg,
  });

  double? get avgNet =>
      (avgEaten != null && avgBurned != null) ? avgEaten! - avgBurned! : null;

  /// How far apart the two answers are. Null when either side is missing.
  double? get divergenceKg => (predictedKg != null && actualKg != null)
      ? (predictedKg! - actualKg!).abs()
      : null;
}

/// Energy density of body mass, kcal per kg. The same constant the engine measures with.
const _kcalPerKg = 7700.0;

/// Build the day rows, newest first.
///
/// [burnedFor] resolves that day's measured expenditure — the caller supplies it because
/// running the full engine per day is the caller's decision, not this function's.
List<DaySummary> daySummaries({
  required List<WeighIn> weighIns,
  required Map<int, double> intakeByDay,
  required Map<String, int> waterByDate,
  required Map<String, ({int done, int due})> ticksByDate,
  required String today,
  required int days,
  double? Function(int dayNum)? burnedFor,
}) {
  final trend = weightTrend(weighIns);
  final raw = {for (final w in weighIns) dayNumber(w.date): w.kg};
  final todayNum = dayNumber(today);

  final out = <DaySummary>[];
  for (var d = todayNum; d > todayNum - days; d--) {
    final date = fromDayNumber(d);
    final ticks = ticksByDate[date];
    final at = trendAt(trend, d, maxStaleDays: 0);
    out.add(DaySummary(
      date: date,
      dayNum: d,
      kcal: intakeByDay[d]?.round(),
      waterMl: waterByDate[date],
      weightKg: raw[d],
      // Only a point measured *on* that day, not one carried forward — a trend line
      // drawn through a gap is a projection, and a history row should not present a
      // projection as a record.
      trendKg: at?.day == d ? at?.trend : null,
      burned: burnedFor?.call(d),
      ticksDone: ticks?.done ?? 0,
      ticksDue: ticks?.due ?? 0,
    ));
  }
  return out;
}

/// Summarise a window of day rows.
///
/// [rows] must be newest-first and cover exactly the window.
RangeSummary summarise(List<DaySummary> rows, List<WeighIn> weighIns, int todayNum) {
  final days = rows.length;
  final withData = rows.where((r) => !r.isEmpty).toList();

  double? mean(Iterable<num?> xs) {
    final vs = xs.whereType<num>().toList();
    return vs.isEmpty ? null : vs.fold<double>(0, (a, v) => a + v) / vs.length;
  }

  // Predicted sums one delta per day that has both sides. Days without a logged
  // intake contribute nothing rather than a zero — an unlogged day is unknown, and
  // treating it as a fast would manufacture a deficit that never happened.
  final deltas = rows
      .where((r) => r.kcal != null && r.burned != null)
      .map((r) => (r.kcal! - r.burned!) / _kcalPerKg)
      .toList();

  // `predicted` sums N daily deltas, so `actual` must span N intervals — N+1 trend
  // points. Measuring between the newest and oldest *rows* spans only N-1 and quietly
  // understates the change (§5.4).
  final trend = weightTrend(weighIns);
  final actual = trendDelta(trend, todayNum, days - 1);

  return RangeSummary(
    days: days,
    logged: withData.length,
    avgEaten: mean(withData.map((r) => r.kcal)),
    avgBurned: mean(withData.map((r) => r.burned)),
    avgWater: mean(withData.map((r) => r.waterMl)),
    ticksDone: rows.fold(0, (a, r) => a + r.ticksDone),
    ticksDue: rows.fold(0, (a, r) => a + r.ticksDue),
    predictedKg: deltas.length < 2 ? null : deltas.fold<double>(0, (a, v) => a + v),
    actualKg: actual,
  );
}

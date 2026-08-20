/// What the app can work out about you from what it already stores.
///
/// Pure — no Flutter, no clock, no I/O — so all of it is testable off-device, which
/// matters here more than usual: these are the parts most likely to be quietly wrong,
/// and a wrong insight is worse than no insight.
///
/// Deliberately nothing here invents data. Everything is derived from the food log, the
/// weight trend and the engine's own output. No cloud, no nutrition API, no inference
/// about the user beyond what they typed.
library;

import '../core/tdee.dart';
import 'foods.dart';

/// One logged item, flattened out of the store so this file need not import it.
///
/// `Entry` lives in `store.dart`, which pulls in Flutter for `ChangeNotifier`. Taking a
/// record instead keeps this layer provable without a widget test.
typedef LoggedItem = ({
  String date,
  String name,
  String unit,
  double qty,
  int kcal,
  Meal meal,
});

// --------------------------------------------------------------- 1. log drift

enum DriftKind {
  /// Not enough evidence, or the two figures agree.
  none,

  /// Measured burn sits far below the formula: food is going unrecorded.
  underLogging,

  /// Measured burn sits far above it.
  overLogging,
}

class LogDrift {
  final DriftKind kind;

  /// Size of the daily gap in kcal, always positive. Zero when [kind] is none.
  final double kcalPerDay;

  /// The gap as a share of the formula estimate, 0–1.
  final double share;

  const LogDrift({required this.kind, this.kcalPerDay = 0, this.share = 0});

  static const LogDrift none = LogDrift(kind: DriftKind.none);
}

/// How far measured burn must fall below the formula before it means anything.
///
/// This is the number that decides whether the app tells someone their logging is off,
/// so it is set from evidence rather than taste. Running the simulation's personas and
/// averaging the measured figure over their last 20 days gives:
///
///     honest logger        +3%
///     under-records 15%    -9%
///     under-records 25%   -17%
///     under-records 40%   -32%
///
/// §1 puts Mifflin–St Jeor at ±10–15% for any given individual, so anything inside that
/// band is indistinguishable from simply having an unusual metabolism. 18% clears the
/// honest logger and the formula's own error, and still catches the 25% under-recorder.
const driftUnderShare = 0.18;

/// The upward direction needs a wider bar. A genuinely fast metabolism or an active job
/// is common and real, whereas nobody logs food they did not eat by accident.
const driftOverShare = 0.30;

/// Below this confidence the measurement is too green to draw conclusions from.
const driftMinConfidence = 0.6;

/// Compare the measured burn against the formula's independent estimate.
///
/// This is the one thing TrueBurn can say that a food diary cannot, and it works because
/// the two numbers come from different places: the formula knows only height, weight and
/// age, while the measurement comes from the log and the scale. When the log is missing
/// food, the measurement drops away from the formula and nothing else in the app notices
/// — §10.5 documents the consequence, which is that the target quietly tightens.
///
/// **Not** predicted-versus-actual. That pairing looks like the obvious test and is
/// useless for this: measured TDEE is *defined* as average intake minus the weight
/// change, so predicted and actual reconcile by construction and can never disagree
/// enough to report. Verified before this was written, not after.
LogDrift detectDrift(TdeeResult tdee) {
  final measured = tdee.measured;
  if (measured == null || tdee.formula <= 0) return LogDrift.none;
  // A half-formed measurement is not evidence of anything.
  if (tdee.confidence < driftMinConfidence) return LogDrift.none;

  final share = (measured - tdee.formula) / tdee.formula;
  if (share <= -driftUnderShare) {
    return LogDrift(
      kind: DriftKind.underLogging,
      kcalPerDay: tdee.formula - measured,
      share: share.abs(),
    );
  }
  if (share >= driftOverShare) {
    return LogDrift(
      kind: DriftKind.overLogging,
      kcalPerDay: measured - tdee.formula,
      share: share,
    );
  }
  return LogDrift.none;
}

// ---------------------------------------------------------- 2. portion memory

/// How much of this food the user normally logs.
///
/// The mode, not the mean: someone who logs 2 roti nine times and 5 once wants 2 next
/// time, and an average would offer 2.3 — a quantity they have never once eaten.
///
/// Null until there are at least two records, because one is a coincidence.
double? typicalQty(List<LoggedItem> log, String name) {
  final counts = <double, int>{};
  var total = 0;
  for (final e in log) {
    if (e.name != name) continue;
    counts[e.qty] = (counts[e.qty] ?? 0) + 1;
    total++;
  }
  if (total < 2) return null;
  var best = 1.0, bestCount = 0;
  for (final entry in counts.entries) {
    // Ties go to the larger quantity: under-offering costs a tap, over-offering costs
    // a correction, and both are cheap — but the larger one is more often right for
    // someone whose portions are growing.
    if (entry.value > bestCount ||
        (entry.value == bestCount && entry.key > best)) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  return best;
}

/// How strongly this food belongs to this meal, 0 upwards.
///
/// Recency alone puts last night's biryani at the top of the breakfast list. What people
/// actually want is what they usually eat *at this hour*.
int mealAffinity(List<LoggedItem> log, String name, Meal meal) {
  var n = 0;
  for (final e in log) {
    if (e.name == name && e.meal == meal) n++;
  }
  return n;
}

/// Food names ordered by how often they appear in this meal, strongest first.
///
/// Only names with a real association are returned — a single appearance is not a
/// habit, and padding this list with one-offs would push the genuine habits down.
List<String> habitualFor(List<LoggedItem> log, Meal meal, {int minCount = 2}) {
  final counts = <String, int>{};
  for (final e in log) {
    if (e.meal != meal) continue;
    counts[e.name] = (counts[e.name] ?? 0) + 1;
  }
  final names = counts.entries.where((e) => e.value >= minCount).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return names.map((e) => e.key).toList();
}

// ------------------------------------------------------------- 3. repeat meal

class RepeatableMeal {
  final Meal meal;
  final String date;
  final List<LoggedItem> items;
  const RepeatableMeal(this.meal, this.date, this.items);

  int get kcal => items.fold(0, (a, e) => a + e.kcal);
}

/// The most recent version of [meal] before [today], if there is one worth repeating.
///
/// Most people eat repetitively, so re-entering the same breakfast item by item is the
/// commonest wasted minute in the app — and §8.1 names logging coverage, not accuracy,
/// as the thing the whole product depends on. Every tap removed protects the
/// measurement.
///
/// Returns null when the meal has already been logged today: offering to repeat
/// something you have just entered invites double-counting.
RepeatableMeal? repeatableMeal(List<LoggedItem> log, Meal meal, String today) {
  if (log.any((e) => e.date == today && e.meal == meal)) return null;

  final dates = log
      .where((e) => e.meal == meal && e.date.compareTo(today) < 0)
      .map((e) => e.date)
      .toList()
    ..sort();
  if (dates.isEmpty) return null;

  final latest = dates.last;
  final items =
      log.where((e) => e.date == latest && e.meal == meal).toList();
  return items.isEmpty ? null : RepeatableMeal(meal, latest, items);
}

// -------------------------------------------------------- 4. weigh-in sanity

enum WeighInVerdict { ok, farFromTrend }

class WeighInCheck {
  final WeighInVerdict verdict;

  /// Signed difference from the trend, kg.
  final double delta;

  const WeighInCheck(this.verdict, this.delta);
}

/// Beyond this far from the trend, a weigh-in is more likely a typo than a body.
///
/// Real day-to-day weight moves a kilo or two on water and food alone, and the trend
/// exists precisely so those swings do not matter — so the threshold has to sit well
/// clear of them or it would cry wolf every Monday. Three kilos in a day is not
/// physiology.
const weighInSuspectKg = 3.0;

/// Sanity-check a weigh-in against the trend it is about to join.
///
/// Weight is the input every other number derives from, so one fat-fingered entry
/// corrupts the expenditure measurement for weeks — and unlike a mistyped food, nothing
/// downstream will ever look obviously wrong. Cheap to ask, expensive to miss.
WeighInCheck checkWeighIn(double kg, double? trend) {
  if (trend == null) return const WeighInCheck(WeighInVerdict.ok, 0);
  final delta = kg - trend;
  return WeighInCheck(
    delta.abs() >= weighInSuspectKg
        ? WeighInVerdict.farFromTrend
        : WeighInVerdict.ok,
    delta,
  );
}

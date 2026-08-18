/// Weight trend.
///
/// Raw daily weight swings ±1–2 kg on water, glycogen and gut content alone. Anything
/// that differences raw weigh-ins — including the TDEE measurement — is differencing
/// mostly noise. So the trend line is the primary number everywhere in the app, and
/// raw weight is shown only as scattered dots behind it.
library;

import 'dart:math' as math;

import 'dates.dart';
import 'types.dart';

/// ~7-day effective window.
const double trendAlpha = 0.25;

class TrendPoint {
  final ISODate date;
  final int day;
  final double raw;
  final double trend;
  const TrendPoint(this.date, this.day, this.raw, this.trend);
}

/// Time-aware EMA: the smoothing factor is compounded across the gap since the last
/// weigh-in, so a user who skips four days does not get a trend line lagging four days
/// behind reality. With no gaps this reduces exactly to a standard EMA.
List<TrendPoint> weightTrend(List<WeighIn> weighIns, {double alpha = trendAlpha}) {
  final sorted = [...weighIns]..sort((a, b) => dayNumber(a.date) - dayNumber(b.date));
  final out = <TrendPoint>[];
  double? trend;
  var prevDay = 0;

  for (final w in sorted) {
    final day = dayNumber(w.date);
    if (trend == null) {
      trend = w.kg;
    } else {
      final gap = math.max(1, day - prevDay);
      final alphaEff = 1 - math.pow(1 - alpha, gap);
      trend = trend + alphaEff * (w.kg - trend);
    }
    prevDay = day;
    out.add(TrendPoint(w.date, day, w.kg, trend));
  }
  return out;
}

/// Trend value as of [day], using the most recent point at or before it.
///
/// Returns null when the newest available point is more than [maxStaleDays] old — an
/// eleven-day-old weight is not evidence about today, and silently reusing it would let
/// the TDEE measurement invent a deficit out of a logging gap.
TrendPoint? trendAt(List<TrendPoint> points, int day, {int maxStaleDays = 7}) {
  TrendPoint? best;
  for (final p in points) {
    if (p.day <= day && (best == null || p.day > best.day)) best = p;
  }
  if (best == null || day - best.day > maxStaleDays) return null;
  return best;
}

/// Trend change over the trailing [days], or null if there is not enough history.
double? trendDelta(List<TrendPoint> points, int asOfDay, int days) {
  final end = trendAt(points, asOfDay);
  final start = trendAt(points, asOfDay - days);
  if (end == null || start == null || end.day == start.day) return null;
  return end.trend - start.trend;
}

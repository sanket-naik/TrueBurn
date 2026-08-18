/// Calendar arithmetic on `YYYY-MM-DD` strings.
///
/// Parsed manually rather than through DateTime.parse, so that a user in IST and a
/// test running in UTC agree on what day it is. Every date in the system is a local
/// calendar date; there are no timestamps anywhere in the engine.
library;

import 'types.dart';

const int _msPerDay = 86400000;

/// Days since 1970-01-01, treating the input as a bare calendar date.
int dayNumber(ISODate date) {
  final y = int.tryParse(date.substring(0, 4));
  final m = int.tryParse(date.substring(5, 7));
  final d = int.tryParse(date.substring(8, 10));
  if (y == null || m == null || d == null) {
    throw ArgumentError('bad ISODate: $date');
  }
  return DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ _msPerDay;
}

ISODate fromDayNumber(int day) {
  final dt = DateTime.fromMillisecondsSinceEpoch(day * _msPerDay, isUtc: true);
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '${dt.year}-$m-$d';
}

ISODate addDays(ISODate date, int n) => fromDayNumber(dayNumber(date) + n);

int daysBetween(ISODate from, ISODate to) => dayNumber(to) - dayNumber(from);

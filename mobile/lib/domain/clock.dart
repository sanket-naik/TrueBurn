/// Clock helpers. Times are stored 24h `HH:MM`; am/pm is only ever a display concern.
library;

int minsOf(String t) =>
    int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));

String clockOf(int m) {
  final v = ((m % 1440) + 1440) % 1440;
  return '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
}

/// "9 am", "6:30 pm" — zero minutes dropped, because the clutter buys nothing.
String ampm(String t) {
  final m = minsOf(t);
  final hh = m ~/ 60;
  final mm = m % 60;
  final h12 = hh % 12 == 0 ? 12 : hh % 12;
  return '$h12${mm != 0 ? ':${mm.toString().padLeft(2, '0')}' : ''} ${hh < 12 ? 'am' : 'pm'}';
}

String hourLabel(int hh) => '${hh % 12 == 0 ? 12 : hh % 12}${hh < 12 ? 'a' : 'p'}';

String isoOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int minutesOfDay(DateTime d) => d.hour * 60 + d.minute;

/// 0 = Sunday, matching the day masks used by routines.
int dowOf(DateTime d) => d.weekday % 7;

const dowShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const dowInitial = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

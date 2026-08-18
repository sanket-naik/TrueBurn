/// Routines — reminders the user creates and owns.
///
/// Deliberately *outside* `lib/core/`. Core is the energy engine; a routine is a
/// commitment tracker. Keeping them apart is what structurally guarantees §7.2: this
/// file has no way to write into a LogBook, so a gym tick cannot reach the TDEE
/// arithmetic even by mistake.
library;

import 'clock.dart';

enum RoutineType { water, food, gym, custom }

extension RoutineTypeLabel on RoutineType {
  String get label => switch (this) {
        RoutineType.water => 'Water',
        RoutineType.food => 'Food',
        RoutineType.gym => 'Gym',
        RoutineType.custom => 'Custom',
      };
}

class Routine {
  final String id;
  final RoutineType type;
  final String name;
  final String message;

  /// Sorted `HH:MM` list. There is no interval builder — a bare "every N hours" beside
  /// two time fields explains nothing (§7.2).
  final List<String> times;

  /// 0 = Sunday.
  final List<int> days;

  /// Water only: millilitres logged per completion.
  final int amountMl;
  final int totalDays;
  final int elapsed;
  final bool active;

  /// Times ticked today and yesterday. Completion is per reminder, not per day (§7.3).
  final List<String> done;
  final List<String> doneYesterday;
  final String lastRollover;

  /// When this routine started being tracked — the date it was created or last resumed,
  /// and the minute of that day.
  ///
  /// Without it, adding a meal routine at 11 pm instantly reports three missed
  /// reminders for a day the routine did not exist in. You cannot miss something that
  /// was never scheduled.
  final String startedDate;
  final int startedMin;

  /// Completions per past day, `YYYY-MM-DD` -> count ticked. Pruned to five weeks.
  ///
  /// Kept because the week view needs it and `done`/`doneYesterday` only reach back one
  /// day. Counts, not times: enough for adherence, far smaller than a full log.
  final Map<String, int> history;

  const Routine({
    required this.id,
    required this.type,
    required this.name,
    required this.message,
    required this.times,
    required this.days,
    required this.amountMl,
    required this.totalDays,
    required this.elapsed,
    required this.active,
    required this.done,
    required this.doneYesterday,
    required this.lastRollover,
    required this.startedDate,
    required this.startedMin,
    this.history = const {},
  });

  Routine copyWith({
    RoutineType? type,
    String? name,
    String? message,
    List<String>? times,
    List<int>? days,
    int? amountMl,
    int? totalDays,
    int? elapsed,
    bool? active,
    List<String>? done,
    List<String>? doneYesterday,
    String? lastRollover,
    String? startedDate,
    int? startedMin,
    Map<String, int>? history,
  }) =>
      Routine(
        id: id,
        type: type ?? this.type,
        name: name ?? this.name,
        message: message ?? this.message,
        times: times ?? this.times,
        days: days ?? this.days,
        amountMl: amountMl ?? this.amountMl,
        totalDays: totalDays ?? this.totalDays,
        elapsed: elapsed ?? this.elapsed,
        active: active ?? this.active,
        done: done ?? this.done,
        doneYesterday: doneYesterday ?? this.doneYesterday,
        lastRollover: lastRollover ?? this.lastRollover,
        startedDate: startedDate ?? this.startedDate,
        startedMin: startedMin ?? this.startedMin,
        history: history ?? this.history,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'message': message,
        'times': times,
        'days': days,
        'amountMl': amountMl,
        'totalDays': totalDays,
        'elapsed': elapsed,
        'active': active,
        'done': done,
        'doneYesterday': doneYesterday,
        'lastRollover': lastRollover,
        'startedDate': startedDate,
        'startedMin': startedMin,
        'history': history,
      };

  static Routine fromJson(Map<String, dynamic> j) => Routine(
        id: j['id'] as String,
        type: RoutineType.values.firstWhere((t) => t.name == j['type']),
        name: j['name'] as String,
        message: j['message'] as String,
        times: (j['times'] as List).cast<String>(),
        days: (j['days'] as List).cast<int>(),
        amountMl: j['amountMl'] as int,
        totalDays: j['totalDays'] as int,
        elapsed: j['elapsed'] as int,
        active: j['active'] as bool,
        done: (j['done'] as List).cast<String>(),
        doneYesterday: (j['doneYesterday'] as List).cast<String>(),
        lastRollover: j['lastRollover'] as String,
        // Routines stored before this field existed were active for the whole day.
        startedDate: j['startedDate'] as String? ?? '',
        startedMin: j['startedMin'] as int? ?? 0,
        history: (j['history'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)) ??
            const {},
      );
}

class Template {
  final String name;
  final String message;
  final List<String> times;
  final List<int> days;
  final int amountMl;
  const Template(this.name, this.message, this.times, this.days, this.amountMl);
}

const _everyDay = [0, 1, 2, 3, 4, 5, 6];

/// Ready-made schedules — what makes a working water routine two taps.
///
/// Water stops at 7 pm rather than 9 pm: six reminders instead of seven keeps the
/// default under the density warning and off bedtime. At 500 ml each that is 3.0 L,
/// which clears a typical 2.75 L target — a default that fails its own coverage check
/// would be indefensible.
const Map<RoutineType, Template> templates = {
  RoutineType.water: Template('Drink water', 'Time for a glass.',
      ['09:00', '11:00', '13:00', '15:00', '17:00', '19:00'], _everyDay, 500),
  RoutineType.food: Template('Log your meals', 'Log what you ate. Takes 20 seconds.',
      ['08:30', '13:00', '17:00', '20:30'], _everyDay, 0),
  RoutineType.gym: Template('Gym session', 'Session time.', ['18:30'], [1, 3, 5], 0),
  RoutineType.custom: Template('', '', ['09:00'], _everyDay, 0),
};

bool dueOn(Routine r, int dow) => r.days.contains(dow);

int perWeek(Routine r) => r.times.length * r.days.length;

String dayText(Routine r) {
  if (r.days.length == 7) return 'every day';
  final weekday = r.days.length == 5 && !r.days.contains(0) && !r.days.contains(6);
  if (weekday) return 'weekdays';
  if (r.days.length == 2 && r.days.contains(0) && r.days.contains(6)) return 'weekends';
  return r.days.map((d) => dowShort[d]).join(' ');
}

String whenText(Routine r) {
  if (r.times.isEmpty) return dayText(r);
  if (r.times.length == 1) return '${ampm(r.times.first)} · ${dayText(r)}';
  return '${r.times.length} times a day · ${ampm(r.times.first)}–'
      '${ampm(r.times.last)} · ${dayText(r)}';
}

/// How each scheduled slot stands right now.
///
/// One function so the card pips, the timeline and the counts cannot disagree — the
/// same single-source-of-truth rule the rest of the app follows.
enum SlotState {
  /// Ticked.
  done,

  /// Its time passed while the routine was active, and it was not ticked.
  missed,

  /// Still ahead today.
  upcoming,

  /// Its time had already passed when the routine was created or resumed, so it was
  /// never scheduled and cannot be missed.
  untracked,
}

/// Minute of today from which this routine was actually being tracked. Zero when it
/// has been active since before today began.
int trackedFromMin(Routine r, String today) =>
    r.startedDate == today ? r.startedMin : 0;

SlotState slotState(Routine r, String time, int nowMin, int trackedFrom, bool paused) {
  if (r.done.contains(time)) return SlotState.done;
  final m = minsOf(time);
  if (m < trackedFrom) return SlotState.untracked;
  if (m < nowMin && !paused) return SlotState.missed;
  return SlotState.upcoming;
}

/// Times due today that passed, while tracked, without a tick.
List<String> missedTimes(Routine r, int dow, int nowMin, bool paused, String today) {
  if (!r.active || paused || !dueOn(r, dow)) return const [];
  final from = trackedFromMin(r, today);
  return r.times
      .where((t) => slotState(r, t, nowMin, from, paused) == SlotState.missed)
      .toList();
}

/// Slots that were ever going to fire today — the honest denominator for "x of N".
int trackedCount(Routine r, int dow, String today) {
  if (!dueOn(r, dow)) return 0;
  final from = trackedFromMin(r, today);
  return r.times.where((t) => minsOf(t) >= from).length;
}

/// The reminder a tick button should target: the oldest genuinely-lapsed one, else the
/// next one up. Slots from before the routine existed are skipped — offering to tick
/// them invites the user to record something that never happened.
String? nextTime(Routine r, int nowMin, String today) {
  final from = trackedFromMin(r, today);
  final pending = r.times
      .where((t) => !r.done.contains(t) && minsOf(t) >= from)
      .toList();
  if (pending.isEmpty) return null;
  final lapsed = pending.where((t) => minsOf(t) < nowMin).toList();
  return lapsed.isNotEmpty ? lapsed.first : pending.first;
}

/// Water contributed by ticked reminders. Derived, so it can never drift from the ticks.
int waterFromRoutines(List<Routine> rs) => rs.fold(
    0,
    (s, r) => s +
        (r.type == RoutineType.water && r.amountMl > 0 ? r.done.length * r.amountMl : 0));

/// Roll `done` into `doneYesterday` when the calendar date changes.
Routine rollover(Routine r, String today, String yesterday) {
  if (r.lastRollover == today) return r;
  final carried = r.lastRollover == yesterday ? r.done : const <String>[];

  // Bank the day that just ended, then prune — five weeks is more than the week view
  // needs and keeps the stored blob small.
  final hist = Map<String, int>.from(r.history);
  if (r.lastRollover.isNotEmpty && r.lastRollover != today) {
    hist[r.lastRollover] = r.done.length;
  }
  if (hist.length > 35) {
    final keys = hist.keys.toList()..sort();
    for (final k in keys.take(hist.length - 35)) {
      hist.remove(k);
    }
  }

  return r.copyWith(
    history: hist,
    doneYesterday: carried,
    done: const [],
    lastRollover: today,
    elapsed: r.elapsed + 1,
    // A new day means it has been tracked since midnight.
    startedDate: '',
    startedMin: 0,
  );
}

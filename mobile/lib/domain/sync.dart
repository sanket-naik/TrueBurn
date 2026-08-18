/// The two-way sync rules between Today and Routines (§7.4).
///
/// Pure functions over plain data — no store, no widgets — so the rules that keep the
/// two screens from disagreeing can be proven headlessly, exactly as the engine is.
library;

import 'clock.dart';
import 'routine.dart';

class WaterSplit {
  final List<Routine> routines;

  /// Millilitres still unattributed to any reminder.
  final int manualMl;
  const WaterSplit(this.routines, this.manualMl);
}

/// Convert accumulated unattributed water into reminder ticks.
///
/// Works on the running pool, not on a single tap. With a +100 ml button, five taps make
/// a 500 ml bottle and must satisfy a 500 ml reminder exactly as one +500 tap does —
/// otherwise the timeline shows a miss for water the user demonstrably drank.
///
/// Invariant: a conversion moves `amountMl` out of the pool and adds one tick worth
/// `amountMl`, so `manualMl + ticks × amountMl` is unchanged by this function.
WaterSplit convertWater(
  List<Routine> routines,
  int manualMl,
  int nowMin,
  int dow,
  bool paused,
) {
  if (paused) return WaterSplit(routines, manualMl);
  var pool = manualMl;

  final next = routines.map((r) {
    if (r.type != RoutineType.water || !r.active || r.amountMl <= 0 || !dueOn(r, dow)) {
      return r;
    }
    final done = [...r.done];
    for (final t in r.times) {
      if (pool < r.amountMl) break;
      // Never reach forward: a reminder set for later today is not satisfied by
      // drinking now, because the user has not got there yet.
      if (minsOf(t) > nowMin || done.contains(t)) continue;
      done.add(t);
      pool -= r.amountMl;
    }
    return done.length == r.done.length ? r : r.copyWith(done: done..sort());
  }).toList();

  return WaterSplit(next, pool);
}

/// A food routine is a reminder *to log*, so the act of logging satisfies it.
///
/// Without this, someone who logs every meal from the Today screen sees a wall of missed
/// reminders and reasonably concludes the app is broken. Ticks the most recent reminder
/// already due — never a future one, which the user has not reached yet.
List<Routine> satisfyFood(List<Routine> routines, int nowMin, int dow, bool paused) {
  if (paused) return routines;
  return routines.map((r) {
    if (r.type != RoutineType.food || !r.active || !dueOn(r, dow)) return r;
    final due = r.times.where((t) => minsOf(t) <= nowMin && !r.done.contains(t)).toList();
    if (due.isEmpty) return r;
    return r.copyWith(done: [...r.done, due.last]..sort());
  }).toList();
}

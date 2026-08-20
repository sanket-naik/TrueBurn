/// Proves the domain rules that would be expensive to debug on a phone: the Today ⇄
/// Routines sync invariant (§7.4), and that the app's data shape drives the engine
/// through its three modes at the right thresholds (§4.4).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:trueburn/core/dates.dart';
import 'package:trueburn/core/report.dart';
import 'package:trueburn/core/tdee.dart';
import 'package:trueburn/core/types.dart';
import 'package:trueburn/core/weight_trend.dart';
import 'package:trueburn/domain/clock.dart';
import 'package:trueburn/domain/foods.dart';
import 'package:trueburn/domain/history.dart';
import 'package:trueburn/domain/routine.dart';
import 'package:trueburn/domain/sync.dart';
import 'package:trueburn/widgets/week_grid.dart';

const nowMin = 13 * 60 + 20; // 1:20 pm
const dow = 1; // Monday
const today = '2026-08-17';

Routine r({
  RoutineType type = RoutineType.water,
  List<String>? times,
  int amountMl = 500,
  List<String> done = const [],
  bool active = true,
  String startedDate = '',
  int startedMin = 0,
  List<int>? days,
  Map<String, int> history = const {},
}) =>
    Routine(
      id: 'r1',
      type: type,
      name: 'test',
      message: '',
      times: times ?? [...templates[RoutineType.water]!.times],
      days: days ?? const [0, 1, 2, 3, 4, 5, 6],
      amountMl: amountMl,
      totalDays: 30,
      elapsed: 0,
      active: active,
      done: done,
      doneYesterday: const [],
      lastRollover: '2026-08-17',
      startedDate: startedDate,
      startedMin: startedMin,
      history: history,
    );

int total(List<Routine> rs, int pool) => pool + waterFromRoutines(rs);

void main() {
  group('water sync invariant', () {
    test('adding X ml raises the total by exactly X', () {
      final rs = [r(done: ['09:00', '11:00'])];
      final before = total(rs, 400);
      for (final ml in [100, 250, 500, 1000]) {
        final s = convertWater(rs, 400 + ml, nowMin, dow, false);
        expect(total(s.routines, s.manualMl), before + ml, reason: '+$ml ml');
      }
    });

    test('five +100 taps satisfy one 500 ml reminder', () {
      var pool = 0;
      var cur = [r()];
      for (var i = 0; i < 5; i++) {
        final s = convertWater(cur, pool + 100, nowMin, dow, false);
        cur = s.routines;
        pool = s.manualMl;
      }
      expect(cur.first.done.length, 1);
      expect(total(cur, pool), 500);
    });

    test('never reaches forward past now', () {
      final s = convertWater([r()], 9000, nowMin, dow, false);
      expect(s.routines.first.done.every((t) => minsOf(t) <= nowMin), isTrue);
      expect(s.manualMl, greaterThan(0));
    });

    test('paused converts nothing', () {
      final s = convertWater([r()], 5000, nowMin, dow, true);
      expect(s.routines.first.done, isEmpty);
    });

    test('a gym routine never absorbs water', () {
      final s = convertWater(
          [r(type: RoutineType.gym, amountMl: 0, times: ['18:30'])], 5000, nowMin, dow, false);
      expect(s.manualMl, 5000);
    });
  });

  group('a routine cannot miss slots from before it existed', () {
    // Reported from the device: a meal routine added at 11 pm immediately claimed three
    // missed reminders for a day it had not been active in.
    Routine addedAt(int min) => r(
          type: RoutineType.food,
          amountMl: 0,
          times: [...templates[RoutineType.food]!.times], // 08:30 13:00 17:00 20:30
          startedDate: today,
          startedMin: min,
        );

    test('added at 11 pm, nothing is missed', () {
      final late = addedAt(23 * 60);
      expect(missedTimes(late, dow, 23 * 60 + 5, false, today), isEmpty);
    });

    test('those slots read as untracked, not missed', () {
      final late = addedAt(23 * 60);
      final from = trackedFromMin(late, today);
      for (final t in late.times) {
        expect(slotState(late, t, 23 * 60 + 5, from, false), SlotState.untracked);
      }
    });

    test('the denominator only counts slots that could fire', () {
      expect(trackedCount(addedAt(23 * 60), dow, today), 0);
      expect(trackedCount(addedAt(14 * 60), dow, today), 2); // 17:00 and 20:30
      expect(trackedCount(addedAt(0), dow, today), 4);
    });

    test('a slot after creation still counts as missed', () {
      final noon = addedAt(12 * 60);
      // 13:00 is after creation and now past, so it is a genuine miss; 08:30 is not.
      final missed = missedTimes(noon, dow, 14 * 60, false, today);
      expect(missed, ['13:00']);
    });

    test('tick targets the next real slot, never a pre-creation one', () {
      expect(nextTime(addedAt(23 * 60), 23 * 60 + 5, today), isNull);
      expect(nextTime(addedAt(12 * 60), 14 * 60, today), '13:00');
    });

    test('a routine active since before today is tracked all day', () {
      final old = r(
        type: RoutineType.food,
        amountMl: 0,
        times: [...templates[RoutineType.food]!.times],
        startedDate: '2026-08-01',
      );
      expect(trackedFromMin(old, today), 0);
      expect(missedTimes(old, dow, 23 * 60, false, today).length, 4);
    });
  });

  group('the week grid never turns an unknown day into a failed one', () {
    // The grid is read as a judgement whether or not it is meant as one, so every cell
    // that is not a real measurement has to be visibly absent rather than empty-at-zero.
    // Columns run 2026-08-11 (Tue) .. 2026-08-17 (Mon, today).

    test('a rest day is off, not zero', () {
      final gym = r(type: RoutineType.gym, times: ['18:30'], days: const [1, 3, 5]);
      final row = weekCells([gym], today, dow).first;
      expect(row[0].kind, CellKind.off); // Tue
      expect(row[6].kind, isNot(CellKind.off)); // Mon, due
    });

    test('a scheduled day with no record is unknown, not zero', () {
      final row = weekCells([r()], today, dow).first;
      expect(row.take(6).map((c) => c.kind), everyElement(CellKind.unknown));
    });

    test('history drives the fill', () {
      // Six water slots; three ticked on the Friday.
      final w = r(history: const {'2026-08-14': 3});
      final row = weekCells([w], today, dow).first;
      expect(row[3].kind, CellKind.tracked);
      expect(row[3].ratio, closeTo(0.5, 1e-9));
    });

    test('a recorded day of zero is tracked, not unknown', () {
      final row = weekCells([r(history: const {'2026-08-14': 0})], today, dow).first;
      expect(row[3].kind, CellKind.tracked);
      expect(row[3].ratio, 0);
    });

    test('today uses the tracked denominator, not every slot', () {
      // Added at 11 pm: nothing was ever scheduled, so today is off — not 0% done.
      final late = r(startedDate: today, startedMin: 23 * 60);
      expect(weekCells([late], today, dow).first[6].kind, CellKind.off);

      // Added at 2 pm: three of six slots were trackable (15:00, 17:00, 19:00), one
      // ticked -> a third, not a sixth.
      final noon = r(startedDate: today, startedMin: 14 * 60, done: const ['15:00']);
      final cell = weekCells([noon], today, dow).first[6];
      expect(cell.kind, CellKind.tracked);
      expect(cell.ratio, closeTo(1 / 3, 1e-9));
    });

    test('shortening the schedule cannot push an old day past full', () {
      final w = r(times: ['09:00'], history: const {'2026-08-14': 6});
      expect(weekCells([w], today, dow).first[3].ratio, 1.0);
    });

    test('only today carries the today marker', () {
      final row = weekCells([r()], today, dow).first;
      expect(row.where((c) => c.isToday).length, 1);
      expect(row[6].isToday, isTrue);
    });
  });

  group('rollover banks the day that ended', () {
    test('yesterday lands in history with its tick count', () {
      final w = r(done: const ['09:00', '11:00']).copyWith(lastRollover: '2026-08-16');
      final rolled = rollover(w, today, '2026-08-16');
      expect(rolled.history['2026-08-16'], 2);
      expect(rolled.done, isEmpty);
      expect(rolled.doneYesterday, ['09:00', '11:00']);
    });

    test('history is pruned to five weeks, oldest first', () {
      final old = {for (var i = 1; i <= 40; i++) '2026-07-${i.toString().padLeft(2, '0')}': 1};
      final w = r(history: old).copyWith(lastRollover: '2026-08-16');
      final rolled = rollover(w, today, '2026-08-16');
      expect(rolled.history.length, 35);
      expect(rolled.history.containsKey('2026-08-16'), isTrue);
      expect(rolled.history.containsKey('2026-07-01'), isFalse);
    });

    test('rolling twice in a day is a no-op', () {
      final w = r(done: const ['09:00']).copyWith(lastRollover: today);
      expect(identical(rollover(w, today, '2026-08-16'), w), isTrue);
    });
  });

  group('history reports what was recorded, and nothing more', () {
    List<DaySummary> build({
      Map<int, double> intake = const {},
      Map<String, int> water = const {},
      List<WeighIn> weighIns = const [],
      double? Function(int)? burned,
      int days = 7,
    }) =>
        daySummaries(
          weighIns: weighIns,
          intakeByDay: intake,
          waterByDate: water,
          ticksByDate: const {},
          today: today,
          days: days,
          burnedFor: burned,
        );

    test('an unlogged day is null everywhere, not zero', () {
      final rows = build();
      expect(rows.length, 7);
      expect(rows.every((r) => r.isEmpty), isTrue);
      expect(rows.first.kcal, isNull);
      expect(rows.first.waterMl, isNull);
      expect(rows.first.net, isNull);
    });

    test('rows run newest first', () {
      final rows = build();
      expect(rows.first.date, today);
      expect(rows.last.date, '2026-08-11');
    });

    test('an unlogged day is left out of the averages, not counted as zero', () {
      final rows = build(
        intake: {dayNumber(today): 2000, dayNumber(today) - 1: 2400},
        burned: (_) => 2200,
      );
      final sum = summarise(rows, const [], dayNumber(today));
      expect(sum.logged, 2);
      // 2200, not (2000 + 2400) / 7.
      expect(sum.avgEaten, closeTo(2200, 1e-9));
    });

    test('predicted sums only days that have both sides', () {
      final rows = build(
        intake: {dayNumber(today): 2000, dayNumber(today) - 1: 2000},
        burned: (d) => d == dayNumber(today) ? 2500 : null,
      );
      final sum = summarise(rows, const [], dayNumber(today));
      // One usable day is not enough to call a trend.
      expect(sum.predictedKg, isNull);
    });

    test('predicted is the sum of daily deltas over 7700', () {
      final rows = build(
        intake: {for (var i = 0; i < 3; i++) dayNumber(today) - i: 2000},
        burned: (_) => 2500,
      );
      final sum = summarise(rows, const [], dayNumber(today));
      expect(sum.predictedKg, closeTo(3 * -500 / 7700, 1e-9));
    });

    test('actual spans N intervals, not N-1', () {
      // Seven daily rows means six intervals between the first and last weigh-in.
      // Measuring newest-to-oldest *row* would span five and understate the change.
      final weighIns = [
        for (var i = 0; i < 7; i++)
          WeighIn(fromDayNumber(dayNumber(today) - i), 80.0 + i * 0.1),
      ];
      final sum = summarise(build(weighIns: weighIns), weighIns, dayNumber(today));
      expect(sum.actualKg, isNotNull);
      // Trend is smoothed, so the exact figure is not 0.6 — but it must be negative
      // (weight fell towards today) and must not be zero.
      expect(sum.actualKg! < 0, isTrue);
    });

    test('a trend point is only reported on the day it was measured', () {
      const weighIns = [WeighIn('2026-08-14', 80.0)];
      final rows = build(weighIns: weighIns);
      expect(rows.firstWhere((r) => r.date == '2026-08-14').trendKg, isNotNull);
      // Carrying it forward would present a projection as a record.
      expect(rows.firstWhere((r) => r.date == '2026-08-15').trendKg, isNull);
    });

    test('divergence is absolute and null-safe', () {
      const a = RangeSummary(days: 7, logged: 7, predictedKg: -0.5, actualKg: -0.2);
      expect(a.divergenceKg, closeTo(0.3, 1e-9));
      const b = RangeSummary(days: 7, logged: 7, predictedKg: -0.5);
      expect(b.divergenceKg, isNull);
    });
  });

  group('food sync', () {
    test('logging ticks the most recent already-due reminder, never a future one', () {
      final food = r(
        type: RoutineType.food,
        amountMl: 0,
        times: [...templates[RoutineType.food]!.times],
        done: ['08:30'],
      );
      final after = satisfyFood([food], nowMin, dow, false);
      expect(after.first.done, contains('13:00'));
      expect(after.first.done, isNot(contains('17:00')));
    });

    test('a second log does not double-tick the same slot', () {
      final food = r(
          type: RoutineType.food,
          amountMl: 0,
          times: [...templates[RoutineType.food]!.times],
          done: ['08:30']);
      final once = satisfyFood([food], nowMin, dow, false);
      final twice = satisfyFood(once, nowMin, dow, false);
      expect(twice.first.done.length, once.first.done.length);
    });

    test('a gym routine is never satisfied by food', () {
      final gym = r(type: RoutineType.gym, amountMl: 0, times: ['18:30']);
      expect(satisfyFood([gym], nowMin, dow, false).first.done, isEmpty);
    });
  });

  group('engine modes', () {
    const profile = Profile(
      heightCm: 175,
      birthYear: 1994,
      formulaVariant: FormulaVariant.mifflinMale,
      activityLevel: ActivityLevel.light,
      goal: LoseGoal(0.5),
    );

    LogBook build(int days) {
      final w = <WeighIn>[];
      final f = <FoodEntry>[];
      for (var i = 0; i < days; i++) {
        final d = DateTime.utc(2026, 7, 1 + i);
        final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
        w.add(WeighIn(date, 82 - i * 0.07 + (i % 3) * 0.15));
        f.add(FoodEntry(date, 2000, 'day'));
      }
      return LogBook(weighIns: w, food: f);
    }

    TdeeResult modeAt(int days) {
      final log = build(days);
      return dailyReport(profile, log, log.weighIns.last.date, 2026).energy.tdee;
    }

    test('1 and 10 days stay on the formula', () {
      expect(modeAt(1).mode, TdeeMode.formula);
      expect(modeAt(10).mode, TdeeMode.formula);
    });

    // 13 weigh-ins is a 12-day *span*, where confidence is exactly zero — measurement
    // becomes possible, not trustworthy. Claiming "measured" here overstates by weeks.
    test('13 days is still formula: a 12-day span has zero confidence', () {
      expect(modeAt(13).mode, TdeeMode.formula);
      expect(modeAt(13).confidence, 0);
    });

    test('15 days blends, with low confidence', () {
      final m = modeAt(15);
      expect(m.mode, TdeeMode.blended);
      expect(m.confidence, greaterThan(0));
      expect(m.confidence, lessThan(0.35));
    });

    test('28 days measures', () {
      final m = modeAt(28);
      expect(m.mode, TdeeMode.measured);
      expect(m.measured, isNotNull);
      expect(m.measured!, greaterThan(1500));
    });

    test('the trend is smoother than the raw weigh-ins', () {
      final log = build(28);
      final trend = weightTrend(log.weighIns);
      double jitter(List<double> xs) {
        var s = 0.0;
        for (var i = 1; i < xs.length; i++) {
          s += (xs[i] - xs[i - 1]).abs();
        }
        return s / (xs.length - 1);
      }

      expect(jitter(trend.map((p) => p.trend).toList()),
          lessThan(jitter(log.weighIns.map((w) => w.kg).toList())));
    });
  });

  group('food list', () {
    test('no duplicate names', () {
      // The catalogue is edited by hand and grew from 73 to 200+ in one sitting;
      // eleven duplicates slipped in on that pass. A duplicate is not cosmetic — it
      // splits a food's history between two identical-looking rows, so portion memory
      // and meal habits both learn half of what they should.
      final names = seedFoods.map((f) => f.n).toList();
      expect(names.length, names.toSet().length,
          reason: 'duplicate food names in seedFoods');
    });

    test('every food has a unit and a sane calorie figure', () {
      for (final f in seedFoods) {
        expect(f.n.trim(), isNotEmpty);
        expect(f.u.trim(), isNotEmpty, reason: '${f.n} has no unit');
        expect(f.k, greaterThanOrEqualTo(0), reason: '${f.n} has negative kcal');
        expect(f.k, lessThan(1200), reason: '${f.n} looks like a typo at ${f.k} kcal');
      }
    });

    final recents = ['Dal tadka', 'Roti / chapati'];
    final custom = [const Food("Amma's sambar", '1 katori', 160)];

    test('three groups, recents first, custom in its own', () {
      final g = browseGroups(recents, custom);
      expect(g.length, 3);
      expect(g[0].label, 'Recent');
      expect(g[0].items.first.n, 'Dal tadka');
      expect(g[1].items.any((f) => f.n == "Amma's sambar"), isTrue);
    });

    test('tail is lightest-first and never capped', () {
      final tail = browseGroups(recents, custom)[2].items;
      for (var i = 1; i < tail.length; i++) {
        expect(tail[i - 1].k, lessThanOrEqualTo(tail[i].k));
      }
      expect(tail.any((f) => f.n == 'Chicken biryani'), isTrue,
          reason: 'a length cap would bury every heavy item');
    });
  });

  group('display helpers', () {
    test('am/pm drops zero minutes', () {
      expect(ampm('09:00'), '9 am');
      expect(ampm('18:30'), '6:30 pm');
      expect(ampm('12:00'), '12 pm');
      expect(ampm('00:00'), '12 am');
    });

    test('meal windows split correctly', () {
      expect(mealFor(9 * 60), Meal.breakfast);
      expect(mealFor(13 * 60), Meal.lunch);
      expect(mealFor(17 * 60), Meal.snack);
      expect(mealFor(20 * 60), Meal.dinner);
    });
  });
}

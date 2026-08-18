/// App state, persisted locally.
///
/// Every mutation goes through `_set`, which notifies and saves. That single choke point
/// is what keeps Today and Routines from disagreeing — they are two views of one object,
/// never two copies (§7.4).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/dates.dart';
import 'core/report.dart';
import 'core/tdee.dart';
import 'core/types.dart';
import 'domain/history.dart';
import 'domain/clock.dart';
import 'domain/foods.dart';
import 'domain/routine.dart';
import 'domain/sync.dart';
import 'notifications.dart';

enum ThemeChoice { light, dark, auto }

class Entry {
  final String id;
  final String date;
  final String name;
  final String unit;
  final double qty;
  final int kcal;
  final Meal meal;
  const Entry(this.id, this.date, this.name, this.unit, this.qty, this.kcal, this.meal);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'name': name,
        'unit': unit,
        'qty': qty,
        'kcal': kcal,
        'meal': meal.name,
      };

  static Entry fromJson(Map<String, dynamic> j) => Entry(
        j['id'] as String,
        j['date'] as String,
        j['name'] as String,
        j['unit'] as String,
        (j['qty'] as num).toDouble(),
        j['kcal'] as int,
        Meal.values.firstWhere((m) => m.name == j['meal']),
      );
}

const _key = 'trueburn.state.v1';

class Store extends ChangeNotifier {
  Profile profile = const Profile(
    heightCm: 175,
    birthYear: 1994,
    formulaVariant: FormulaVariant.mifflinMale,
    activityLevel: ActivityLevel.light,
    goal: LoseGoal(0.5),
  );

  List<WeighIn> weighIns = [];
  List<Entry> entries = [];
  List<Routine> routines = [];
  List<String> recents = [];
  List<Food> customFoods = [];

  String waterDate = '';
  int manualWaterMl = 0;

  /// Total millilitres per past day, `YYYY-MM-DD` -> ml. Banked at rollover.
  ///
  /// Water was only ever stored for today, so history could show food and weight for a
  /// past day but had nothing to say about water. Keeping the daily total — not the
  /// individual taps — is enough for every screen that asks, and costs a few bytes a
  /// day. Days before this existed are absent, and read as "not recorded" rather than
  /// as zero.
  Map<String, int> waterLog = {};

  /// Whether the first-launch tour has been finished or skipped.
  ///
  /// Skipping counts as seen. A tour that reappears because you dismissed it is a
  /// nag, and it would be the first thing the app did wrong.
  bool tourSeen = false;

  ThemeChoice theme = ThemeChoice.auto;
  String quietFrom = '22:00';
  String quietTo = '07:00';

  /// Session-only. A pause is a deliberate, short-lived act; persisting it risks the
  /// app coming back silent days later with no explanation.
  int? pausedUntilMin;

  bool hydrated = false;

  bool get paused => pausedUntilMin != null;
  bool get hasWeight => weighIns.isNotEmpty;

  int get waterMl => manualWaterMl + waterFromRoutines(routines);

  int consumedKcal(String date) =>
      entries.where((e) => e.date == date).fold(0, (a, e) => a + e.kcal);

  /// Bumped by every mutation, so the memo below knows when it is stale.
  int _version = 0;
  DailyReport? _cachedReport;
  String? _cachedFor;
  int _cachedVersion = -1;

  /// The daily report, memoised.
  ///
  /// The engine itself is cheap — ~350us with a year of data, about 2% of a frame — but
  /// it was being recomputed several times per build by different cards. Caching on
  /// (state version, date) makes repeat calls within a frame free, which is what lets
  /// widgets ask for it wherever they need it without threading it through.
  DailyReport report([DateTime? now]) {
    final d = now ?? DateTime.now();
    final today = isoOf(d);
    if (_cachedReport != null && _cachedFor == today && _cachedVersion == _version) {
      return _cachedReport!;
    }
    final r = _compute(today, d.year);
    _cachedReport = r;
    _cachedFor = today;
    _cachedVersion = _version;
    return r;
  }

  /// Past days plus their range summary.
  ///
  /// Runs the engine once per day in the window — about 350us each with a year of data,
  /// so ~10ms for a month, paid once when the sheet opens rather than per build. It is
  /// the same `dailyReport` the Today screen uses, asked about a different date, which
  /// is the whole reason the engine takes `asOfDate` instead of reading a clock.
  ({List<DaySummary> rows, RangeSummary summary}) history(int days, [DateTime? now]) {
    final d = now ?? DateTime.now();
    final today = isoOf(d);
    final todayNum = dayNumber(today);

    final log = LogBook(
      weighIns: weighIns,
      food: entries.map((e) => FoodEntry(e.date, e.kcal.toDouble(), e.name)).toList(),
      water: const [],
    );

    final ticks = <String, ({int done, int due})>{};
    for (var i = 0; i < days; i++) {
      final date = fromDayNumber(todayNum - i);
      final dow = DateTime.parse(date).weekday % 7;
      var done = 0, due = 0;
      for (final r in routines) {
        if (!dueOn(r, dow)) continue;
        if (i == 0) {
          done += r.done.length;
          due += trackedCount(r, dow, today);
        } else {
          final h = r.history[date];
          if (h == null) continue;
          done += h;
          due += r.times.length;
        }
      }
      if (due > 0 || done > 0) ticks[date] = (done: done, due: due);
    }

    final water = {...waterLog};
    if (waterDate.isNotEmpty && waterMl > 0) water[waterDate] = waterMl;

    final rows = daySummaries(
      weighIns: weighIns,
      intakeByDay: dailyIntake(log.food),
      waterByDate: water,
      ticksByDate: ticks,
      today: today,
      days: days,
      burnedFor: (dayNum) {
        final r = dailyReport(profile, log, fromDayNumber(dayNum), d.year);
        return r.energy.tdee.mode == TdeeMode.formula ? null : r.energy.tdee.kcal;
      },
    );

    return (rows: rows, summary: summarise(rows, weighIns, todayNum));
  }

  DailyReport _compute(String today, int year) {
    return dailyReport(
      profile,
      LogBook(
        weighIns: weighIns,
        food: entries.map((e) => FoodEntry(e.date, e.kcal.toDouble(), e.name)).toList(),
        water: [WaterEntry(today, waterMl)],
      ),
      today,
      year,
    );
  }

  // ------------------------------------------------------------- lifecycle

  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) _decode(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A stored shape from an older build should degrade to a fresh start rather
      // than crash on launch.
    }
    hydrated = true;
    rolloverDay();
    await applyPendingTicks();
    notifyListeners();
    await syncNotifications();
  }

  /// Apply completions banked by the lock screen while the app was not running.
  ///
  /// The background isolate can only queue; this is where the queue becomes state. Runs
  /// on launch and on resume, so a Done tapped at 3pm is reflected the moment you open
  /// the app — not lost, and not requiring the app to have been alive.
  Future<void> applyPendingTicks() async {
    final pending = await Notifications.drainPending();
    if (pending.isEmpty) return;
    _set(() {
      routines = routines.map((r) {
        final mine = pending.where((p) => p.routineId == r.id).map((p) => p.time);
        final add = mine.where((t) => r.times.contains(t) && !r.done.contains(t)).toList();
        return add.isEmpty ? r : r.copyWith(done: [...r.done, ...add]..sort());
      }).toList();
    });
  }

  /// The OS schedule is a projection of the routines — rebuilt, never patched.
  Future<void> syncNotifications() => Notifications.syncAll(
        routines,
        quietFrom: quietFrom,
        quietTo: quietTo,
        paused: paused,
      );

  void _set(void Function() mutate) {
    mutate();
    _version++;
    notifyListeners();
    if (hydrated) _save();
  }

  /// Mutations that change *what should fire* also rebuild the OS schedule.
  void _setAndReschedule(void Function() mutate) {
    _set(mutate);
    if (hydrated) unawaited(syncNotifications());
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_encode()));
    } catch (_) {
      /* nothing to recover from; state stays correct in memory */
    }
  }

  Map<String, dynamic> _encode() => {
        'profile': {
          'heightCm': profile.heightCm,
          'birthYear': profile.birthYear,
          'variant': profile.formulaVariant.name,
          'activity': profile.activityLevel.name,
          'goal': switch (profile.goal) {
            LoseGoal(kgPerWeek: final r) => {'kind': 'lose', 'rate': r},
            GainGoal(kgPerWeek: final r) => {'kind': 'gain', 'rate': r},
            MaintainGoal() => {'kind': 'maintain'},
          },
        },
        'weighIns': weighIns.map((w) => {'date': w.date, 'kg': w.kg}).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'routines': routines.map((r) => r.toJson()).toList(),
        'recents': recents,
        'customFoods': customFoods.map((f) => f.toJson()).toList(),
        'waterDate': waterDate,
        'manualWaterMl': manualWaterMl,
        'waterLog': waterLog,
        'tourSeen': tourSeen,
        'theme': theme.name,
        'quietFrom': quietFrom,
        'quietTo': quietTo,
      };

  void _decode(Map<String, dynamic> j) {
    final p = j['profile'] as Map<String, dynamic>;
    final g = p['goal'] as Map<String, dynamic>;
    profile = Profile(
      heightCm: (p['heightCm'] as num).toDouble(),
      birthYear: p['birthYear'] as int,
      formulaVariant:
          FormulaVariant.values.firstWhere((v) => v.name == p['variant']),
      activityLevel: ActivityLevel.values.firstWhere((v) => v.name == p['activity']),
      goal: switch (g['kind']) {
        'lose' => LoseGoal((g['rate'] as num).toDouble()),
        'gain' => GainGoal((g['rate'] as num).toDouble()),
        _ => const MaintainGoal(),
      },
    );
    weighIns = (j['weighIns'] as List)
        .map((w) => WeighIn(w['date'] as String, (w['kg'] as num).toDouble()))
        .toList();
    entries = (j['entries'] as List)
        .map((e) => Entry.fromJson(e as Map<String, dynamic>))
        .toList();
    routines = (j['routines'] as List)
        .map((r) => Routine.fromJson(r as Map<String, dynamic>))
        .toList();
    recents = (j['recents'] as List).cast<String>();
    customFoods = (j['customFoods'] as List)
        .map((f) => Food.fromJson(f as Map<String, dynamic>))
        .toList();
    waterDate = j['waterDate'] as String? ?? '';
    manualWaterMl = j['manualWaterMl'] as int? ?? 0;
    waterLog = (j['waterLog'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)) ??
        {};
    // Anyone upgrading has already been using the app; the tour is for new installs.
    tourSeen = j['tourSeen'] as bool? ?? true;
    theme = ThemeChoice.values.firstWhere((t) => t.name == j['theme'],
        orElse: () => ThemeChoice.auto);
    quietFrom = j['quietFrom'] as String? ?? '22:00';
    quietTo = j['quietTo'] as String? ?? '07:00';
  }

  /// Roll `done` into `doneYesterday` and reset the day's water when the date changes.
  void rolloverDay() {
    final today = isoOf(DateTime.now());
    if (waterDate == today && routines.every((r) => r.lastRollover == today)) return;
    final yesterday = fromDayNumber(dayNumber(today) - 1);
    _set(() {
      routines = routines.map((r) => rollover(r, today, yesterday)).toList();
      if (waterDate != today) {
        // Bank the day that just ended, including whatever routine ticks contributed —
        // the same total the Today card was showing a moment ago.
        if (waterDate.isNotEmpty && waterMl > 0) waterLog[waterDate] = waterMl;
        waterDate = today;
        manualWaterMl = 0;
      }
    });
  }

  // ------------------------------------------------------------- water

  void addWater(int ml) {
    final now = DateTime.now();
    _set(() {
      final s = convertWater(
          routines, manualWaterMl + ml, minutesOfDay(now), dowOf(now), paused);
      routines = s.routines;
      manualWaterMl = s.manualMl;
    });
  }

  // ------------------------------------------------------------- food

  void addEntry(Food f, double qty) {
    final now = DateTime.now();
    final nowMin = minutesOfDay(now);
    _set(() {
      entries = [
        ...entries,
        Entry(
          '${now.microsecondsSinceEpoch}',
          isoOf(now),
          f.n,
          f.u,
          qty,
          (f.k * qty).round(),
          mealFor(nowMin),
        ),
      ];
      recents = [f.n, ...recents.where((n) => n != f.n)].take(6).toList();
      routines = satisfyFood(routines, nowMin, dowOf(now), paused);
    });
  }

  void addCustomFood(String name, int kcal) {
    final f = Food(name.trim(), '1 serving', kcal);
    _set(() => customFoods = [f, ...customFoods]);
    addEntry(f, 1);
  }

  void copyYesterday() {
    final now = DateTime.now();
    final today = isoOf(now);
    final yesterday = fromDayNumber(dayNumber(today) - 1);
    final prior = entries.where((e) => e.date == yesterday).toList();
    if (prior.isEmpty) return;
    _set(() {
      entries = [
        ...entries,
        ...prior.map((e) => Entry('${now.microsecondsSinceEpoch}${e.name.hashCode}',
            today, e.name, e.unit, e.qty, e.kcal, e.meal)),
      ];
      routines = satisfyFood(routines, minutesOfDay(now), dowOf(now), paused);
    });
  }

  // ------------------------------------------------------------- weight

  /// One raw weigh-in per day; logging again replaces it rather than double-counting.
  void logWeight(double kg) {
    final date = isoOf(DateTime.now());
    _set(() {
      weighIns = [...weighIns.where((w) => w.date != date), WeighIn(date, kg)]
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  // ------------------------------------------------------------- routines

  void tick(String id, String time) => _set(() {
        routines = routines
            .map((r) => r.id == id && !r.done.contains(time)
                ? r.copyWith(done: [...r.done, time]..sort())
                : r)
            .toList();
      });

  void upsertRoutine(Routine r) => _setAndReschedule(() {
        routines = routines.any((x) => x.id == r.id)
            ? routines.map((x) => x.id == r.id ? r : x).toList()
            : [...routines, r];
      });

  void deleteRoutine(String id) =>
      _setAndReschedule(() => routines = routines.where((r) => r.id != id).toList());

  void toggleRoutine(String id) => _setAndReschedule(() {
        final now = DateTime.now();
        routines = routines.map((r) {
          if (r.id != id) return r;
          final resuming = !r.active;
          // Resuming mid-afternoon must not retroactively mark the morning as missed.
          return r.copyWith(
            active: resuming,
            startedDate: resuming ? isoOf(now) : r.startedDate,
            startedMin: resuming ? minutesOfDay(now) : r.startedMin,
          );
        }).toList();
      });

  Routine newRoutine(RoutineType type) {
    final t = templates[type]!;
    final now = DateTime.now();
    return Routine(
      id: '${now.microsecondsSinceEpoch}',
      type: type,
      name: t.name,
      message: t.message,
      times: [...t.times],
      days: [...t.days],
      amountMl: t.amountMl,
      totalDays: 30,
      elapsed: 0,
      active: true,
      done: const [],
      doneYesterday: const [],
      lastRollover: isoOf(now),
      // Tracked from the moment it is created — never retroactively.
      startedDate: isoOf(now),
      startedMin: minutesOfDay(now),
    );
  }

  void pauseFor(int? untilMin) => _setAndReschedule(() => pausedUntilMin = untilMin);

  // ------------------------------------------------------------- settings

  void setQuietHours({String? from, String? to}) => _setAndReschedule(() {
        if (from != null) quietFrom = from;
        if (to != null) quietTo = to;
      });

  /// Wipe everything. There is no account and no backup, so this is the only delete
  /// there can be — and the confirmation lives in the UI, not here.
  Future<void> eraseAll() async {
    _set(() {
      weighIns = [];
      entries = [];
      routines = [];
      recents = [];
      customFoods = [];
      waterLog = {};
      waterDate = isoOf(DateTime.now());
      manualWaterMl = 0;
      pausedUntilMin = null;
    });
    // Every scheduled alarm belonged to a routine that no longer exists; leaving them
    // armed would have the app pinging about data it has forgotten.
    await syncNotifications();
  }

  void setTheme(ThemeChoice t) => _set(() => theme = t);
  void markTourSeen() => _set(() => tourSeen = true);
  void setProfile(Profile p) => _set(() => profile = p);
  void setQuiet(String from, String to) => _setAndReschedule(() {
        quietFrom = from;
        quietTo = to;
      });
}

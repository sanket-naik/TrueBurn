import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/clock.dart';
import '../domain/routine.dart';
import '../notifications.dart';
import '../sheets/sheets.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/week_grid.dart';
import '../widgets/primitives.dart';

class RoutinesScreen extends StatefulWidget {
  final Store store;
  const RoutinesScreen(this.store, {super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  Store get s => widget.store;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final now = DateTime.now();
    final nowMin = minutesOfDay(now);
    final dow = dowOf(now);
    final today = isoOf(now);

    final active = s.routines.where((r) => r.active).toList();
    final idle = s.routines.where((r) => !r.active).toList();
    final perDayTotal = active.fold(0, (a, r) => a + r.times.length);

    final yesterday = isoOf(now.subtract(const Duration(days: 1)));

    ({int done, int due}) tally(bool isYest) {
      final d = isYest ? (dow + 6) % 7 : dow;
      var done = 0, due = 0;
      for (final r in active) {
        if (!dueOn(r, d)) continue;
        // `doneYesterday` only carries when the app rolled over *from* yesterday. After
        // a gap of a few days it is empty, which would report a truthful-looking "0
        // done" for a day that was never measured — so the banked count wins when it
        // exists. Both are written by the same rollover, so they cannot disagree.
        done += isYest ? (r.history[yesterday] ?? r.doneYesterday.length) : r.done.length;
        due += r.times.length;
      }
      return (done: done, due: due);
    }

    final y = tally(true);
    final t = tally(false);
    final missed = active.fold(
      0,
      (a, r) => a + missedTimes(r, dow, nowMin, s.paused, today).length,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      children: [
        Row(
          children: [
            Expanded(child: Text('Routines', style: screenTitle(c))),
            // Debug-only: long-press the count to fire a reminder in 10s, so the
            // lock-screen Done action can be checked without waiting for 9 am.
            GestureDetector(
              onLongPress: !kDebugMode || active.isEmpty
                  ? null
                  : () {
                      Notifications.fireTestIn(
                        const Duration(seconds: 10),
                        active.first,
                        active.first.times.first,
                      );
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Test reminder in 10s')));
                    },
              child: Num('$perDayTotal/DAY', size: 11, color: c.ink3),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (s.paused) ...[
          Notice(
            'Paused until ${ampm(clockOf(s.pausedUntilMin!))}. Day counts keep running, '
            'so a pause costs no progress.',
            tone: 'warn',
          ),
          const SizedBox(height: 8),
          Pill('Resume now', tone: c.warn, onTap: () => setState(() => s.pauseFor(null))),
          const SizedBox(height: 18),
        ],

        if (active.isNotEmpty) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Label('Reminders'),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'yest ', style: sans(c, size: 11.5)),
                          TextSpan(text: '${y.done}/${y.due}', style: mono(c, size: 11.5)),
                          TextSpan(text: ' · today ', style: sans(c, size: 11.5)),
                          TextSpan(text: '${t.done}/${t.due}', style: mono(c, size: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                WeekGrid(
                  routines: s.routines,
                  today: today,
                  todayDow: dow,
                  trailing: missed > 0
                      ? Num('$missed missed today', size: 10.5, color: c.warn)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                'New routine',
                onTap: () {
                  showRoutineSheet(
                    context,
                    s,
                    s.newRoutine(RoutineType.water),
                    true,
                  ).then((_) => setState(() {}));
                },
              ),
            ),
            if (!s.paused) ...[
              const SizedBox(width: 9),
              Expanded(child: PrimaryButton('Pause all', ghost: true, onTap: _pauseAll)),
            ],
          ],
        ),
        const SizedBox(height: 18),

        Label('Active · ${active.length}'),
        const SizedBox(height: 11),
        if (active.isEmpty)
          _starters(c)
        else
          for (final r in active) ...[
            _card(c, r, nowMin, dow, today),
            const SizedBox(height: 11),
          ],

        if (idle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Label('Paused · ${idle.length}'),
          const SizedBox(height: 11),
          for (final r in idle) ...[
            _card(c, r, nowMin, dow, today),
            const SizedBox(height: 11),
          ],
        ],
      ],
    );
  }

  void _pauseAll() {
    final c = AppTheme.of(context);
    final nowMin = minutesOfDay(DateTime.now());
    showAppSheet(context, (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pause everything',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600, color: c.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing fires until then. Day counts keep running, so a pause costs no progress.',
              style: sans(c),
            ),
            const SizedBox(height: 16),
            for (final o in [
              (60, '1 hour'),
              (240, '4 hours'),
              (-2, 'Rest of today'),
              (-1, 'Until tomorrow'),
            ]) ...[
              Pill(
                '${o.$2} · until ${o.$1 == -1
                    ? 'tomorrow morning'
                    : o.$1 == -2
                    ? 'midnight'
                    : ampm(clockOf(nowMin + o.$1))}',
                onTap: () {
                  setState(
                    () => s.pauseFor(
                      o.$1 == -1
                          ? -1
                          : o.$1 == -2
                          ? 1440
                          : nowMin + o.$1,
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
    });
  }

  /// First run: the two reminders that pay for themselves, with the reason each earns it.
  Widget _starters(Palette c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: c.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No routines yet. These two pay for themselves — a water reminder logs the '
          'water for you, and a meal reminder keeps your log complete enough for '
          'TrueBurn to measure anything.',
          style: sans(c),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Pill(
                'Water reminders',
                tone: c.accent,
                onTap: () =>
                    setState(() => s.upsertRoutine(s.newRoutine(RoutineType.water))),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Pill(
                'Meal reminders',
                tone: c.accent,
                onTap: () =>
                    setState(() => s.upsertRoutine(s.newRoutine(RoutineType.food))),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _card(Palette c, Routine r, int nowMin, int dow, String today) {
    final miss = missedTimes(r, dow, nowMin, s.paused, today);
    final due = dueOn(r, dow);
    final next = nextTime(r, nowMin, today);
    final trackedFrom = trackedFromMin(r, today);
    final tracked = trackedCount(r, dow, today);
    // Floored at what has actually been done — see the note on the label below.
    final denom = math.max(tracked, r.done.length);
    final pct = r.elapsed / (r.totalDays == 0 ? 1 : r.totalDays) * 100;

    return Panel(
      borderColor: miss.isNotEmpty ? c.warn : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                showRoutineSheet(context, s, r, false).then((_) => setState(() {})),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: cardTitle(c)),
                      Num(whenText(r), size: 11.5, color: c.ink2),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.ink3),
              ],
            ),
          ),
          const SizedBox(height: 11),

          // Pips say *which* of today's reminders landed. "3 of 6" cannot: it is the
          // difference between knowing you missed two and knowing you missed the afternoon.
          if (due)
            Row(
              children: [
                for (final t in r.times) ...[
                  Builder(
                    builder: (_) {
                      final st = slotState(r, t, nowMin, trackedFrom, s.paused);
                      // An untracked slot — one whose time had passed before the routine
                      // existed — is drawn hollow and grey. Marking it amber would accuse the
                      // user of missing something that was never scheduled.
                      final (Color? fill, Color? border) = switch (st) {
                        SlotState.done => (c.accent, null),
                        SlotState.missed => (null, c.warn),
                        SlotState.upcoming => (c.ink3.withValues(alpha: 0.28), null),
                        SlotState.untracked => (null, c.line),
                      };
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: fill,
                          border: border != null
                              ? Border.all(color: border, width: 1.5)
                              : null,
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${r.done.length}',
                          style: mono(c, size: 12, color: miss.isNotEmpty ? c.warn : c.ink),
                        ),
                        TextSpan(
                          // Denominator counts only the slots that were ever going to
                          // fire today, so a routine added at 11 pm does not read
                          // "0 of 4" — but it is floored at what has actually been
                          // done. Water logged on Today satisfies reminder slots (§7.2)
                          // including ones whose time had already passed when the
                          // routine was created, so completions can outrun the tracked
                          // count and this once read "6 of 0".
                          text: denom == 0
                              ? ' nothing due today'
                              : ' of $denom ${denom == r.times.length ? 'done today' : 'due since you added it'}',
                          style: sans(
                            c,
                            size: 12,
                            color: miss.isNotEmpty ? c.warn : c.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),

          SizedBox(height: due ? 11 : 0),
          Row(
            children: [
              Expanded(child: Meter(pct, thin: true)),
              const SizedBox(width: 10),
              Num('Day ${r.elapsed} of ${r.totalDays}', size: 10.5, color: c.ink3),
            ],
          ),
          const SizedBox(height: 11),

          Row(
            children: [
              Expanded(
                // Ticking the last slot flips this from a button to a status chip. That is
                // the moment of completion, and it used to be a hard cut in the middle of
                // the card the user was looking at.
                child: SmoothSwap(
                  forward: r.active && !s.paused && due && next != null,
                  child: r.active && !s.paused && due && next != null
                      ? Pill(
                          miss.isNotEmpty
                              ? 'Missed ${ampm(miss.first)} — tick'
                              : 'Tick ${ampm(next)}',
                          tone: miss.isNotEmpty ? c.warn : c.accent,
                          onTap: () => setState(() => s.tick(r.id, next)),
                        )
                      // A lone Pause button floating beside an empty gap reads as a layout
                      // bug. When there is nothing left to tick, say so in that space.
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 13),
                          decoration: BoxDecoration(
                            color: due && r.active ? c.accentSoft : c.sunken,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            !r.active
                                ? 'Paused'
                                : s.paused
                                ? 'All paused'
                                : due
                                ? 'All done today'
                                : 'Not due today',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: due && r.active ? c.accent : c.ink3,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 7),
              Pill(
                r.active ? 'Pause' : 'Resume',
                onTap: () => setState(() => s.toggleRoutine(r.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Seven days of adherence, one row per routine.
///
/// This replaced a time-of-day timeline. The timeline answered "when do I slip", which
/// is a real question — but the routine cards directly beneath it already show today's
/// slots as pips, so the summary was restating what was an inch below it. A week view
/// answers the question the cards *cannot*: am I keeping this up, and which one am I
/// dropping.
///
/// Deliberately not a streak display. No consecutive-day counter, no praise, no colour
/// escalation — §6 rule 4 forbids that pattern, and a grid is one bad week away from
/// becoming a guilt machine if you let it keep score.
library;

import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../domain/clock.dart';
import '../domain/routine.dart';
import '../theme.dart';

enum CellKind {
  /// Scheduled, and we know how much of it got done.
  tracked,

  /// Not scheduled that day — a rest day, not a failure.
  off,

  /// Scheduled, but before this routine existed or before the app kept a record.
  /// Drawn as absent: an unknown day must not read as a missed one.
  unknown,
}

class DayCell {
  final CellKind kind;
  final double ratio;
  final bool isToday;
  const DayCell(this.kind, this.ratio, this.isToday);
}

/// Grid data: one row per routine, seven columns oldest-first, today rightmost.
List<List<DayCell>> weekCells(List<Routine> routines, String today, int todayDow) {
  final todayNum = dayNumber(today);
  return routines.map((r) {
    return List.generate(7, (i) {
      final isToday = i == 6;
      final date = isToday ? today : fromDayNumber(todayNum - (6 - i));
      final dow = isToday ? todayDow : DateTime.parse(date).weekday % 7;
      if (!dueOn(r, dow)) return DayCell(CellKind.off, 0, isToday);

      if (isToday) {
        // Tracked slots, not every slot: a routine created at 11 pm should not read as
        // a day mostly failed. Same denominator the card's "x of N" uses.
        final n = trackedCount(r, dow, today);
        if (n == 0) return const DayCell(CellKind.off, 0, true);
        return DayCell(CellKind.tracked, (r.done.length / n).clamp(0, 1), true);
      }

      // Nothing on record — the routine did not exist yet, or the app was not run that
      // day. Either way it is unknown, and unknown is not zero.
      final done = r.history[date];
      if (done == null) return const DayCell(CellKind.unknown, 0, false);
      // Historic slot counts are not stored, so this uses the current schedule. Editing
      // the times shifts old bars; keeping a full per-day log to avoid that costs more
      // than the distortion is worth.
      final total = r.times.length;
      return DayCell(
          CellKind.tracked, total == 0 ? 0 : (done / total).clamp(0, 1), false);
    });
  }).toList();
}

class WeekGrid extends StatelessWidget {
  final List<Routine> routines;
  final String today;
  final int todayDow;

  /// Sits at the right of the footer line, beside the key.
  final Widget? trailing;

  const WeekGrid({
    super.key,
    required this.routines,
    required this.today,
    required this.todayDow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final active = routines.where((r) => r.active).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final cells = weekCells(active, today, todayDow);
    // Nothing but today to show yet. Every new user spends their first week here, so it
    // gets a sentence rather than six columns of grey that read as six days skipped.
    final hasPast = cells.any((row) =>
        row.take(6).any((cell) => cell.kind == CellKind.tracked));

    final todayNum = dayNumber(today);
    final labels = List.generate(7, (i) {
      if (i == 6) return dowInitial[todayDow];
      return dowInitial[DateTime.parse(fromDayNumber(todayNum - (6 - i))).weekday % 7];
    });

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var r = 0; r < active.length; r++) ...[
            _row(
              c,
              SizedBox(
                width: 58,
                child: Text(
                  (active[r].type == RoutineType.custom
                          ? active[r].name
                          : active[r].type.label)
                      .toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle(c),
                ),
              ),
              (i) => _Cell(cells[r][i]),
            ),
            if (r != active.length - 1) const SizedBox(height: 7),
          ],
          const SizedBox(height: 7),
          _row(
            c,
            SizedBox(
              width: 58,
              child: Text('7 DAYS',
                  style: labelStyle(c).copyWith(color: c.ink3, fontSize: 9.5)),
            ),
            (i) => Center(
              child: Text(
                labels[i],
                style: mono(c,
                    size: 9.5,
                    color: i == 6 ? c.ink2 : c.ink3,
                    weight: i == 6 ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(
              child: hasPast
                  ? _fillKey(c)
                  : Text('Fills in from tomorrow',
                      style: sans(c, size: 11, color: c.ink3)),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ]),
        ],
      ),
    );
  }

  /// Gutter plus seven equal columns — the day labels have to land under their cells,
  /// so both rows are built by the same function.
  Widget _row(Palette c, Widget gutter, Widget Function(int) cell) => Row(children: [
        gutter,
        for (var i = 0; i < 7; i++) ...[
          Expanded(child: cell(i)),
          if (i != 6) const SizedBox(width: 6),
        ],
      ]);

  /// A depth ramp, not a colour legend — the cells encode "how much of the day", so the
  /// key has to show the same thing.
  Widget _fillKey(Palette c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('none', style: sans(c, size: 10.5, color: c.ink3)),
        const SizedBox(width: 5),
        for (final a in const [0.0, 0.35, 0.7, 1.0]) ...[
          Container(
            width: 15,
            height: 10,
            decoration: BoxDecoration(
              color: _fill(c, a),
              borderRadius: BorderRadius.circular(3),
              border: a == 0 ? Border.all(color: c.line) : null,
            ),
          ),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 2),
        Text('all', style: sans(c, size: 10.5, color: c.ink3)),
      ]);
}

/// Depth of fill *is* the reading — a heatmap, not a pass/fail badge, so a half-done day
/// looks half done rather than failed.
Color _fill(Palette c, double ratio) =>
    ratio == 0 ? c.sunken : c.accent.withValues(alpha: 0.22 + 0.78 * ratio);

class _Cell extends StatelessWidget {
  final DayCell cell;
  const _Cell(this.cell);

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final today = cell.isToday;

    if (cell.kind != CellKind.tracked) {
      final off = cell.kind == CellKind.off;
      return Semantics(
        label: '${today ? 'Today' : 'Day'}, ${off ? 'not scheduled' : 'no record'}',
        child: Container(
          height: 26,
          decoration: BoxDecoration(
            // Rest days recede to a dash. Unknown days keep an outline but no fill —
            // a hole in the row, deliberately unlike the filled-but-empty box that
            // means "recorded, nothing done".
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: off
                ? null
                : Border.all(color: c.line.withValues(alpha: 0.75)),
          ),
          child: off
              ? Center(
                  child: Container(
                    width: 10,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                )
              : null,
        ),
      );
    }

    final pct = (cell.ratio * 100).round();
    return Semantics(
      label: '${today ? 'Today' : 'Day'}, $pct percent done',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        height: 26,
        decoration: BoxDecoration(
          color: _fill(c, cell.ratio),
          borderRadius: BorderRadius.circular(7),
          border: today
              ? Border.all(color: c.accent, width: 1.6)
              : (cell.ratio == 0 ? Border.all(color: c.line) : null),
        ),
      ),
    );
  }
}

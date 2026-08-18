/// History — a range summary over a day list, and one day in detail.
///
/// The date on Today is the control that opens this (§5.4). No third tab, no extra
/// icon: the date already answers "which day am I looking at", so making it pressable
/// adds the feature without adding chrome.
library;

import 'package:flutter/material.dart';

import '../domain/clock.dart';
import '../domain/foods.dart';
import '../domain/history.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/primitives.dart';

const _pad = EdgeInsets.fromLTRB(18, 12, 18, 24);

Future<void> showHistorySheet(BuildContext context, Store s) => showAppSheet(
  context,
  (ctx) => _HistorySheet(s),
  footer: (ctx) => PrimaryButton('Done', onTap: () => Navigator.pop(ctx)),
);

String _dayLabel(String date) {
  final d = DateTime.parse(date);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  return '${dowShort[d.weekday % 7]} ${d.day} ${months[d.month - 1]}';
}

class _HistorySheet extends StatefulWidget {
  final Store s;
  const _HistorySheet(this.s);
  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // Computed once per build of the sheet, not per row — the engine runs once for each
    // day in the window and that work should not repeat as the list scrolls.
    final h = widget.s.history(_days);
    final sum = h.summary;
    final rows = h.rows;

    return Padding(
      padding: _pad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'History',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600, color: c.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Averages first — a trend engine is judged on its averages, not on any one day.',
            style: sans(c, size: 12, color: c.ink3),
          ),
          const SizedBox(height: 14),

          SegControl<int>(
            value: _days,
            onChanged: (v) => setState(() => _days = v),
            options: const [(7, 'Last 7 days'), (30, 'Last 30 days')],
          ),
          const SizedBox(height: 14),

          _summaryPanel(c, sum),
          const SizedBox(height: 10),
          _checkPanel(c, sum),
          const SizedBox(height: 18),
          Row(
            children: [
              const Label('Day by day'),
              const Spacer(),
              Text(
                '${sum.logged} of ${sum.days} logged',
                style: sans(c, size: 11, color: c.ink3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in rows) ...[
            _DayRow(r, onTap: () => _openDay(r)),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  void _openDay(DaySummary d) => showAppSheet(
    context,
    (ctx) => _DaySheet(widget.s, d),
    footer: (ctx) => PrimaryButton('Done', onTap: () => Navigator.pop(ctx)),
  );

  Widget _summaryPanel(Palette c, RangeSummary sum) {
    String kcal(double? v) => v == null ? '—' : v.round().toString();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('Per day, averaged'),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(c, 'eaten', kcal(sum.avgEaten), 'kcal'),
              _stat(c, 'burned', kcal(sum.avgBurned), 'kcal'),
              _stat(
                c,
                'net',
                sum.avgNet == null
                    ? '—'
                    : '${sum.avgNet! >= 0 ? '+' : '−'}${sum.avgNet!.abs().round()}',
                'kcal',
                tint: sum.avgNet == null ? null : (sum.avgNet! <= 0 ? c.accent : c.warn),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat(
                c,
                'water',
                sum.avgWater == null ? '—' : (sum.avgWater! / 1000).toStringAsFixed(2),
                'L',
              ),
              _stat(
                c,
                'reminders',
                sum.ticksDue == 0 ? '—' : '${sum.ticksDone}/${sum.ticksDue}',
                'ticked',
              ),
              const Spacer(flex: 1),
            ],
          ),
          if (sum.logged < sum.days) ...[
            const SizedBox(height: 12),
            Text(
              '${sum.days - sum.logged} of these days have no record. They are left out of '
              'the averages rather than counted as zero.',
              style: sans(c, size: 11.5, color: c.ink3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(Palette c, String label, String value, String unit, {Color? tint}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: labelStyle(c)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Num(value, size: 21, color: tint ?? c.ink),
                const SizedBox(width: 3),
                Text(unit, style: sans(c, size: 10.5, color: c.ink3)),
              ],
            ),
          ],
        ),
      );

  /// The engine checking itself in public. When the two agree the measurement is sound;
  /// when they diverge something has moved — logging drift, or expenditure — and the
  /// user is better served seeing that than being handed a tidy number that hides it.
  Widget _checkPanel(Palette c, RangeSummary sum) {
    String kg(double? v) =>
        v == null ? '—' : '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(2)} kg';

    final div = sum.divergenceKg;
    final agrees = div != null && div < 0.35;

    return Panel(
      borderColor: div == null ? null : (agrees ? c.accent : c.warn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('The check'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PREDICTED', style: labelStyle(c)),
                    const SizedBox(height: 3),
                    Num(kg(sum.predictedKg), size: 19),
                    Text('from what you ate', style: sans(c, size: 10.5, color: c.ink3)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTUAL', style: labelStyle(c)),
                    const SizedBox(height: 3),
                    Num(kg(sum.actualKg), size: 19),
                    Text('from the scale', style: sans(c, size: 10.5, color: c.ink3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (div == null)
            Notice(
              sum.predictedKg == null
                  ? 'Not enough logged days yet to predict a change. Two days with both '
                        'food and a measured burn is the minimum.'
                  : 'Not enough weigh-ins across this window to compare against.',
            )
          else
            Notice(
              agrees
                  ? 'These agree to within ${div.toStringAsFixed(2)} kg, which is the '
                        'result you want: the expenditure figure is doing its job.'
                  : 'These are ${div.toStringAsFixed(2)} kg apart. Usually that means '
                        'logging has drifted — portions creeping up, or meals going '
                        'unlogged — rather than the scale being wrong.',
              tone: agrees ? 'accent' : 'warn',
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DaySummary d;
  final VoidCallback onTap;
  const _DayRow(this.d, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final empty = d.isEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: empty ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 86,
                child: Text(
                  _dayLabel(d.date),
                  style: sans(
                    c,
                    size: 13,
                    color: empty ? c.ink3 : c.ink,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              if (empty)
                Expanded(
                  child: Text('nothing logged', style: sans(c, size: 12, color: c.ink3)),
                )
              else ...[
                Expanded(
                  child: Row(
                    children: [
                      if (d.kcal != null) _chip(c, '${d.kcal}', 'kcal'),
                      if (d.waterMl != null)
                        _chip(c, (d.waterMl! / 1000).toStringAsFixed(1), 'L'),
                      if (d.weightKg != null)
                        _chip(c, d.weightKg!.toStringAsFixed(1), 'kg'),
                      if (d.ticksDue > 0) _chip(c, '${d.ticksDone}/${d.ticksDue}', ''),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.ink3),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(Palette c, String v, String unit) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Num(v, size: 13, color: c.ink),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(unit, style: sans(c, size: 10, color: c.ink3)),
        ],
      ],
    ),
  );
}

/// One day, deliberately short: it answers "what did that day look like" and stops.
class _DaySheet extends StatelessWidget {
  final Store s;
  final DaySummary d;
  const _DaySheet(this.s, this.d);

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final meals = <Meal, List<Entry>>{};
    for (final e in s.entries.where((e) => e.date == d.date)) {
      meals.putIfAbsent(e.meal, () => []).add(e);
    }

    return Padding(
      padding: _pad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayLabel(d.date),
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600, color: c.ink),
          ),
          const SizedBox(height: 14),

          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _fig(c, 'EATEN', d.kcal?.toString() ?? '—', 'kcal'),
                    _fig(c, 'BURNED', d.burned?.round().toString() ?? '—', 'kcal'),
                    _fig(
                      c,
                      'NET',
                      d.net == null ? '—' : '${d.net! >= 0 ? '+' : '−'}${d.net!.abs()}',
                      'kcal',
                      tint: d.net == null ? null : (d.net! <= 0 ? c.accent : c.warn),
                    ),
                  ],
                ),
                if (d.burned == null) ...[
                  const SizedBox(height: 12),
                  const Notice(
                    'Expenditure was still being estimated from a formula on this day, '
                    'so there is no measured burn to report.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (meals.isNotEmpty) ...[
            const Label('What you ate'),
            const SizedBox(height: 8),
            for (final m in Meal.values)
              if (meals[m] != null) ...[
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(m.label.toUpperCase(), style: labelStyle(c)),
                          const Spacer(),
                          Num(
                            '${meals[m]!.fold(0, (a, e) => a + e.kcal)} kcal',
                            size: 12,
                            color: c.ink3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final e in meals[m]!)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.name,
                                  style: sans(c, size: 13, color: c.ink2),
                                ),
                              ),
                              Num('${e.kcal}', size: 12.5, color: c.ink3),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _line(
                  c,
                  'Water',
                  d.waterMl == null
                      ? 'not recorded'
                      : '${(d.waterMl! / 1000).toStringAsFixed(2)} L',
                ),
              ),
              Expanded(
                child: _line(
                  c,
                  'Reminders',
                  d.ticksDue == 0 ? 'none due' : '${d.ticksDone} of ${d.ticksDue} ticked',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _line(
                  c,
                  'Weighed',
                  d.weightKg == null
                      ? 'no weigh-in'
                      : '${d.weightKg!.toStringAsFixed(1)} kg',
                ),
              ),
              Expanded(
                child: _line(
                  c,
                  'Trend',
                  d.trendKg == null ? '—' : '${d.trendKg!.toStringAsFixed(2)} kg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fig(Palette c, String label, String value, String unit, {Color? tint}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle(c)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Num(value, size: 20, color: tint ?? c.ink),
                const SizedBox(width: 3),
                Text(unit, style: sans(c, size: 10.5, color: c.ink3)),
              ],
            ),
          ],
        ),
      );

  Widget _line(Palette c, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: labelStyle(c)),
      const SizedBox(height: 3),
      Text(value, style: sans(c, size: 13, color: c.ink2)),
    ],
  );
}

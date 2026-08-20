import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/tdee.dart';
import '../core/weight_trend.dart';
import '../domain/clock.dart';
import '../domain/foods.dart';
import '../domain/insights.dart';
import '../sheets/history.dart';
import '../sheets/sheets.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/primitives.dart';
part 'today_paint.dart';

const measureFrom = 12;
const measureFull = 28;

enum Range { month, quarter, year }

const rangeDays = {Range.month: 30, Range.quarter: 90, Range.year: 365};

class TodayScreen extends StatefulWidget {
  final Store store;
  const TodayScreen(this.store, {super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

String _dateLine(DateTime d) =>
    '${dowShort[d.weekday % 7]} ${d.day} ${_months[d.month - 1]}';

class _TodayScreenState extends State<TodayScreen> {
  Range _range = Range.month;
  int? _armed;

  Store get s => widget.store;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final report = s.report();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Today', style: screenTitle(c)),
              const SizedBox(height: 2),
              // The date is the control that opens history (§5.4). It already answers
              // "which day am I looking at", so making it pressable adds the feature
              // without adding a third tab or a second icon.
              Semantics(
                button: true,
                label: 'Open history',
                child: InkWell(
                  onTap: () => showHistorySheet(context, s),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_dateLine(DateTime.now()).toUpperCase(), style: labelStyle(c)),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more, size: 14, color: c.ink3),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.tune, size: 18, color: c.ink3),
            onPressed: () => showSettingsSheet(context, s),
            tooltip: 'Settings',
          ),
        ]),
        const SizedBox(height: 6),
        if (!s.hasWeight) ..._firstRun(c) else ..._normal(c, report),
      ],
    );
  }

  // ------------------------------------------------------------- first run
  //
  // A dashboard of zeros is the obvious design and the wrong one: it shows nothing,
  // promises nothing, and leaves the user to invent their own reason to return.
  List<Widget> _firstRun(Palette c) => [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Label('Welcome'),
            const SizedBox(height: 6),
            Text('Weigh yourself. That is the whole of today.',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w600, color: c.ink, height: 1.25)),
            const SizedBox(height: 14),
            for (final step in const [
              ('Today', 'One weigh-in. Five seconds, and the app has what it needs to start.'),
              ('This week', 'Log roughly what you eat. Rough is fine — it only has to be consistent.'),
              ('Week three', 'TrueBurn stops estimating and tells you what you actually burn.'),
            ]) ...[
              Label(step.$1, color: c.accent),
              const SizedBox(height: 2),
              Text(step.$2, style: sans(c)),
              const SizedBox(height: 10),
            ],
            PrimaryButton('Log your first weight',
                onTap: () => showWeighSheet(context, s).then((_) => setState(() {}))),
            const SizedBox(height: 10),
            Text(
              'No account, and nothing is sent to us. You can add food and water any '
              'time — they do not need setting up first.',
              style: sans(c, size: 12, color: c.ink3),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _foodCard(c, 0, null),
        const SizedBox(height: 18),
        _waterCard(c, 2500),
      ];

  // ------------------------------------------------------------- normal
  List<Widget> _normal(Palette c, dynamic report) {
    final drift = s.drift();
    final tdee = report.energy.tdee as TdeeResult;
    final target = report.energy.target.kcal as double?;
    final consumed = s.consumedKcal(report.date as String);
    final trend = weightTrend(s.weighIns);
    final spanDays =
        trend.length >= 2 ? trend.last.day - trend.first.day : 0;

    final chipLabel = switch (tdee.mode) {
      TdeeMode.measured => 'Measured',
      TdeeMode.blended => 'Part measured',
      TdeeMode.formula => 'Estimated',
    };

    // `.abs()` on the headline used to hide the sign, so 720 kcal *over* read exactly
    // like 720 kcal *left* — the same digits under the same label, on the number the
    // whole screen exists to communicate. The meter already knew; the headline did not.
    final over = target != null && consumed > target;

    return [
      Panel(
        borderColor: over ? c.warn.withValues(alpha: 0.5) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Label(over ? 'Over by' : 'Left to eat'),
                const SizedBox(height: 6),
                Num(
                  target == null ? '—' : (target - consumed).abs().round().toString(),
                  size: 44,
                  color: over ? c.warn : null,
                ),
              ]),
            ),
            StateChip(chipLabel, measured: tdee.mode != TdeeMode.formula),
          ]),
          if (target != null) ...[
            const SizedBox(height: 12),
            Meter(consumed / target * 100, over: consumed > target),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '$consumed', style: mono(c)),
                TextSpan(text: ' eaten', style: sans(c)),
              ])),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'target ', style: sans(c)),
                TextSpan(text: target.round().toString(), style: mono(c)),
              ])),
            ]),
          ],
          const SizedBox(height: 12),
          Notice(switch (tdee.mode) {
            TdeeMode.measured =>
              'Your expenditure is ${tdee.kcal.round()} kcal, measured from your last '
                  '$measureFull days rather than estimated from your height and weight.',
            TdeeMode.blended =>
              'Your expenditure is ${tdee.kcal.round()} kcal — part measured from your '
                  '$spanDays days of data, part still the starting estimate. It leans '
                  'further on your own numbers each day.',
            TdeeMode.formula =>
              'Your expenditure is ${tdee.kcal.round()} kcal, estimated from your height '
                  'and weight. TrueBurn needs about $measureFrom days between weigh-ins '
                  'before it can start measuring.',
          }),
        ]),
      ),
      if (spanDays < measureFull) ...[
        const SizedBox(height: 18),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Label('Learning your body'),
              Num('$spanDays of $measureFull days', size: 12, color: c.ink2),
            ]),
            const SizedBox(height: 12),
            Meter(spanDays / measureFull * 100, markAt: measureFrom / measureFull * 100),
            const SizedBox(height: 12),
            // Keyed off the engine's own mode, not a threshold compare: at a 12-day span
            // confidence is exactly zero, so `spanDays >= 12` would claim measuring had
            // started while the chip above still correctly reads "Estimated".
            Notice(
              tdee.mode == TdeeMode.formula
                  ? 'Until then your target comes from a population formula, which is '
                      '±10–15% off for any given person.'
                  : 'Measuring has started, but it is not confident yet — your target leans '
                      'further on your own data each day until day $measureFull.',
              tone: tdee.mode == TdeeMode.formula ? 'plain' : 'accent',
            ),
          ]),
        ),
      ],
      if (drift.kind != DriftKind.none) ...[
        const SizedBox(height: 18),
        _driftCard(c, drift),
      ],
      const SizedBox(height: 18),
      _weightCard(c, trend, report),
      const SizedBox(height: 18),
      _foodCard(c, consumed, target),
      const SizedBox(height: 18),
      _waterCard(c, report.water.targetMl as int? ?? 2500),
    ];
  }

  /// The one thing TrueBurn can say that a calorie counter cannot.
  ///
  /// It is the only app holding both numbers — what the food log predicted, and what the
  /// scale actually did — so it is the only one that can notice they disagree. §10.5
  /// documents the failure this catches: intake that is systematically under-recorded
  /// biases the measurement downward and makes the app over-restrict, quietly, for as
  /// long as nobody notices.
  ///
  /// Worded as an observation about the *log*, never about the person. §6 rule 4 rules
  /// out the guilt framing, and it would be wrong anyway — under-recording is the normal
  /// human default, not a character flaw, and the fix is mechanical.
  Widget _driftCard(Palette c, LogDrift drift) {
    final under = drift.kind == DriftKind.underLogging;
    final pct = (drift.share * 100).round();
    final kcal = drift.kcalPerDay.round();

    return Panel(
      borderColor: c.warn.withValues(alpha: 0.45),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.compare_arrows_rounded, size: 16, color: c.warn),
          const SizedBox(width: 7),
          Text(
            under ? 'BURN IS LOWER THAN EXPECTED' : 'BURN IS HIGHER THAN EXPECTED',
            style: labelStyle(c).copyWith(color: c.warn),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          under
              ? 'Your measured burn is about $kcal kcal a day below what your height, '
                  'weight and age predict — $pct% lower.'
              : 'Your measured burn is about $kcal kcal a day above what your height, '
                  'weight and age predict — $pct% higher.',
          style: sans(c, size: 13.5, color: c.ink).copyWith(height: 1.45),
        ),
        const SizedBox(height: 10),
        Text(
          under
              ? 'A gap that size almost always means food is going unrecorded — oils, '
                  'drinks and the bites that never feel like a meal. That is the normal '
                  'human default, not a failing. It matters because TrueBurn measures '
                  'your burn from what you log, so the gap makes your target stricter '
                  'than it needs to be.'
              : 'That can simply be a fast metabolism or an active job, in which case '
                  'nothing is wrong. It can also mean portions were logged larger than '
                  'they were.',
          style: sans(c, size: 12.5, color: c.ink3).copyWith(height: 1.45),
        ),
      ]),
    );
  }

  Widget _weightCard(Palette c, List<TrendPoint> trend, dynamic report) {
    final kg = report.weight.trend as double?;

    // One weigh-in cannot produce a trend, and an empty 92px chart slot reads as a
    // component that failed rather than as "not yet". Say what is missing and why.
    if (trend.length < 2) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Weight', style: cardTitle(c))),
            Pill('Log',
                tone: c.accent,
                onTap: () => showWeighSheet(context, s).then((_) => setState(() {}))),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Num(kg?.toStringAsFixed(1) ?? '—', size: 34),
                const SizedBox(width: 6),
                Text('kg', style: sans(c, size: 14, color: c.ink3)),
              ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Container(height: 2, color: c.line)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            ),
            Expanded(
              child: CustomPaint(
                size: const Size(double.infinity, 2),
                painter: _DashPainter(c.line),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'One more weigh-in and the trend line starts. Daily weight swings a kilo or '
            'two on water alone, so TrueBurn reads the trend rather than the number — and '
            'it needs at least two points to draw one.',
            style: sans(c, size: 12.5, color: c.ink3),
          ),
        ]),
      );
    }

    final days = math.min(rangeDays[_range]!, trend.length);
    final slice = trend.sublist(math.max(0, trend.length - days));
    final delta = slice.last.trend - slice.first.trend;
    final spanDays = slice.last.day - slice.first.day;
    final weeks = math.max(1, spanDays / 7);
    // Zero is not a gain. Only colour it once there is a direction worth naming.
    final flat = delta.abs() < 0.05;
    final tone = flat ? c.ink2 : (delta < 0 ? c.accent : c.warn);

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Weight', style: cardTitle(c)),
              const SizedBox(height: 2),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'trend ', style: sans(c, size: 12, color: c.ink3)),
                TextSpan(
                    text: '${kg?.toStringAsFixed(1)} kg',
                    style: mono(c, size: 12, color: c.ink2)),
              ])),
            ]),
          ),
          Pill('Log',
              tone: c.accent,
              onTap: () => showWeighSheet(context, s).then((_) => setState(() {}))),
        ]),
        const SizedBox(height: 14),
        SegControl<Range>(
          compact: true,
          value: _range,
          onChanged: (v) => setState(() => _range = v),
          options: const [
            (Range.month, 'Month'),
            (Range.quarter, 'Quarter'),
            (Range.year, 'Year'),
          ],
        ),
        const SizedBox(height: 14),
        TrendChart(points: trend, days: rangeDays[_range]!),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Num('${flat ? '' : (delta < 0 ? '−' : '+')}'
                  '${delta.abs().toStringAsFixed(1)} kg',
                  size: 24, color: tone),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'over ${spanDays == 1 ? '1 day' : '$spanDays days'}'
                  '${flat ? '' : ' · ${delta < 0 ? '−' : '+'}'
                      '${(delta.abs() / weeks).toStringAsFixed(2)} kg a week'}',
                  style: sans(c, size: 12, color: c.ink3),
                ),
              ),
            ]),
      ]),
    );
  }

  Widget _foodCard(Palette c, int consumed, double? target) {
    final today = s.report().date;
    final todays = s.entries.where((e) => e.date == today).toList();
    final byMeal = {
      for (final m in Meal.values)
        m: todays.where((e) => e.meal == m).fold(0, (a, e) => a + e.kcal)
    };

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Food', style: cardTitle(c)),
              Text(
                todays.isEmpty
                    ? 'Nothing logged yet'
                    : '$consumed kcal · ${todays.length} item${todays.length == 1 ? '' : 's'}',
                style: sans(c, size: 12, color: c.ink3),
              ),
            ]),
          ),
          Pill('Add',
              tone: c.accent,
              onTap: () => showFoodSheet(context, s, consumed, target)
                  .then((_) => setState(() {}))),
        ]),
        if (target != null && todays.isNotEmpty) ...[
          const SizedBox(height: 12),
          IntakeBar(byMeal: byMeal, total: consumed, target: target.round()),
        ],
      ]),
    );
  }

  Widget _waterCard(Palette c, int targetMl) {
    final ml = s.waterMl;
    final fromRoutines = ml - s.manualWaterMl;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      // The border is a *foreground* decoration, painted after the child. As a normal
      // decoration it is drawn first and then the antialiased clip trims the child
      // right over it, which nibbled the stroke away at the top two corners where the
      // wave reaches the edge. Every other card gets away with a plain border because
      // nothing in it paints to the boundary.
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        WaterWave(pct: math.min(100, ml / targetMl * 100)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 9, crossAxisAlignment: WrapCrossAlignment.end, children: [
              Num('${(ml / 1000).toStringAsFixed(2)} L', size: 30),
              Text(s.hasWeight
                  ? 'of ${(targetMl / 1000).toStringAsFixed(2)} L'
                  : 'no target until you weigh in',
                  style: sans(c, size: 12.5)),
              if (fromRoutines > 0)
                // Appears the instant a reminder is ticked, often while the card is
                // being looked at.
                TweenAnimationBuilder<double>(
                  key: ValueKey(fromRoutines),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (ctx, t, child) => Opacity(opacity: t, child: child),
                  child: Num('$fromRoutines ml from reminders',
                      size: 12, color: c.accent),
                ),
            ]),
            const SizedBox(height: 12),
            // Two-tap add: the first arms, the second commits. A stray tap on a card
            // scrolled past several times a day should not silently rewrite the log.
            //
            // The two rows are the same height, so they slide past each other rather
            // than cutting: arming pushes the amounts out to the left and brings the
            // confirmation in from the right, and cancelling reverses it. A hard swap
            // here read as the card flickering.
            SmoothSwap(
              forward: _armed != null,
              child: _armed != null
                  ? Row(children: [
                      Expanded(
                        child: Pill(
                          'Add ${_armed! >= 1000 ? '${_armed! ~/ 1000} L' : '$_armed ml'}?',
                          tone: c.accent,
                          onTap: () {
                            s.addWater(_armed!);
                            setState(() => _armed = null);
                          },
                        ),
                      ),
                      const SizedBox(width: 7),
                      Pill('Cancel', onTap: () => setState(() => _armed = null)),
                    ])
                  : Row(children: [
                      for (final v in const [100, 250, 500, 1000]) ...[
                        Expanded(
                          child: Pill('+${v >= 1000 ? '${v ~/ 1000} L' : v}',
                              monoFont: true, onTap: () => setState(() => _armed = v)),
                        ),
                        if (v != 1000) const SizedBox(width: 6),
                      ],
                    ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

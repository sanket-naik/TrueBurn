import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/targets.dart';
import '../core/types.dart';
import '../core/weight_trend.dart';
import '../domain/clock.dart';
import '../domain/foods.dart';
import '../domain/routine.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/primitives.dart';

const _pad = EdgeInsets.fromLTRB(18, 12, 18, 24);

TextStyle _title(Palette c) =>
    TextStyle(fontSize: 23, fontWeight: FontWeight.w600, color: c.ink);

InputDecoration _dec(Palette c, String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.ink3),
      filled: true,
      fillColor: c.sunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.accent)),
    );

// ------------------------------------------------------------------ weigh-in

/// One number, and an honest preview of what it does.
///
/// Raw weight swings a kilo or two on water alone, and reacting to that swing is the
/// behaviour the trend exists to prevent — so the sheet shows the trend the entry
/// produces, with the 0.01 precision on the *movement*, which is where the small change
/// actually lives (§4.1).
Future<void> showWeighSheet(BuildContext context, Store s) =>
    showAppSheet(context, (ctx) => _WeighSheet(s));

class _WeighSheet extends StatefulWidget {
  final Store s;
  const _WeighSheet(this.s);
  @override
  State<_WeighSheet> createState() => _WeighSheetState();
}

/// Bounds on a typed weight. Wide enough to cover any real person, narrow enough to
/// catch a slipped decimal point or a value entered in pounds — the same class of error
/// the engine's plausibility guard exists for, caught here where it can still be fixed.
const _minKg = 25.0;
const _maxKg = 350.0;

class _WeighSheetState extends State<_WeighSheet> {
  late double v = widget.s.weighIns.isNotEmpty
      ? (widget.s.weighIns.last.kg * 10).round() / 10
      : 75.0;

  late final TextEditingController _ctl =
      TextEditingController(text: v.toStringAsFixed(1));
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  bool _touched = false;
  bool _rejected = false;

  /// The value as it stood when editing began.
  ///
  /// Not the same as "last valid keystroke". Typing 999 passes through 9, then 99 —
  /// and 99 is a perfectly valid weight, so a naive revert lands on a number the user
  /// never meant and never saw as final. Only what was there before they started
  /// typing is safe to fall back to.
  late double _beforeEdit = v;

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _ctl.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      // Select the whole number on focus so typing replaces it. Otherwise entering 82.4
      // means backspacing 75.0 first, which is the same tedium the steppers had.
      _beforeEdit = v;
      setState(() => _touched = true);
      _ctl.selection = TextSelection(baseOffset: 0, extentOffset: _ctl.text.length);
    } else {
      _commit();
    }
  }

  /// Steppers write through the controller, so the field always shows the live value.
  void _bump(double delta) {
    final next = ((v + delta) * 10).round() / 10;
    setState(() {
      v = next.clamp(_minKg, _maxKg);
      _beforeEdit = v;
      _rejected = false;
      _ctl.text = v.toStringAsFixed(1);
    });
  }

  /// Typing moves the value live so the trend preview below tracks it — but the text is
  /// left exactly as typed. Rewriting it mid-entry fights the cursor and makes "8"
  /// impossible to get through on the way to "82".
  void _typed(String text) {
    final parsed = double.tryParse(text);
    if (parsed == null || parsed < _minKg || parsed > _maxKg) return;
    setState(() {
      v = parsed;
      _rejected = false;
    });
  }

  /// Normalise on blur or Done.
  ///
  /// An out-of-range entry **reverts** rather than clamping. Clamping 999 to 350 would
  /// write a plausible-looking weight that was never measured, and the trend would
  /// carry that lie for weeks; snapping back to the last good value says plainly that
  /// nothing was accepted.
  void _commit() {
    final parsed = double.tryParse(_ctl.text);
    final bad = parsed == null || parsed < _minKg || parsed > _maxKg;
    setState(() {
      _rejected = bad && _ctl.text.isNotEmpty;
      v = bad ? _beforeEdit : (parsed * 10).round() / 10;
      _ctl.text = v.toStringAsFixed(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final trend = weightTrend(widget.s.weighIns);
    final prev = trend.isNotEmpty ? trend.last.trend : v;
    final next = trend.isNotEmpty ? prev + trendAlpha * (v - prev) : v;
    final move = next - prev;
    final loggedToday =
        widget.s.weighIns.any((w) => w.date == isoOf(DateTime.now()));

    return Padding(
      padding: _pad,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Log weight', style: _title(c)),
        const SizedBox(height: 16),
        Row(children: [
          Pill('−',
              semanticLabel: 'Decrease by 0.1 kilograms', onTap: () => _bump(-0.1)),
          Expanded(
            child: Column(children: [
              // The number *is* the input. Steppers alone meant thirty taps to go from
              // 75 to 82, and there was no way to type at all.
              IntrinsicWidth(
                child: TextField(
                  controller: _ctl,
                  focusNode: _focus,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textInputAction: TextInputAction.done,
                  onChanged: _typed,
                  onSubmitted: (_) => _focus.unfocus(),
                  style: display(c, size: 30),
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    enabledBorder:
                        UnderlineInputBorder(borderSide: BorderSide(color: c.line)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: c.accent, width: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // The hint retires once they have used the field — it is scaffolding for
              // the first weigh-in, not a permanent label.
              Text(_touched ? 'kg' : 'kg  ·  tap to type',
                  style: sans(c, size: 11.5, color: c.ink3)),
            ]),
          ),
          Pill('+',
              semanticLabel: 'Increase by 0.1 kilograms', onTap: () => _bump(0.1)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (final d in const [-1.0, -0.5, 0.5, 1.0]) ...[
            Expanded(
              child: Pill('${d > 0 ? '+' : ''}$d',
                  monoFont: true, onTap: () => _bump(d)),
            ),
            if (d != 1.0) const SizedBox(width: 6),
          ],
        ]),
        if (_rejected) ...[
          const SizedBox(height: 10),
          Notice(
            'That is outside ${_minKg.round()}–${_maxKg.round()} kg, so it was not '
            'accepted — check for a slipped decimal point or a value in pounds.',
            tone: 'warn',
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(13),
          decoration:
              BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Trend after this', style: sans(c)),
              Num('${next.toStringAsFixed(1)} kg', size: 17),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Moves the trend by ', style: sans(c, size: 12)),
                TextSpan(
                    text: '${move >= 0 ? '+' : '−'}${move.abs().toStringAsFixed(2)} kg',
                    style: mono(c, size: 12)),
              ])),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'from ', style: sans(c, size: 12)),
                TextSpan(text: prev.toStringAsFixed(1), style: mono(c, size: 12)),
              ])),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Text(
          'Day-to-day weight swings a kilo or two on water and food alone. TrueBurn '
          'records the number you enter but reads the trend, so a heavy morning does not '
          'mean a bad week.',
          style: sans(c, size: 12, color: c.ink3),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: SecondaryButton('Cancel', onTap: () => Navigator.pop(context))),
          const SizedBox(width: 9),
          Expanded(
            child: PrimaryButton(loggedToday ? 'Update' : 'Save', onTap: () {
              // Commit explicitly: tapping Save while the field still has focus would
              // otherwise save the value from before the last keystroke.
              _commit();
              widget.s.logWeight(v);
              Navigator.pop(context);
            }),
          ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------- food

Future<void> showFoodSheet(BuildContext context, Store s, int consumed, double? target) {
  final key = GlobalKey<_FoodSheetState>();
  return showAppSheet(
    context,
    (ctx) => _FoodSheet(s, consumed, target, key: key),
    // Pinned so it is reachable without scrolling seventy items.
    footer: (ctx) => SecondaryButton('+ Add your own food',
        onTap: () => key.currentState?.openCustom()),
  );
}

class _FoodSheet extends StatefulWidget {
  final Store s;
  final int consumed;
  final double? target;
  const _FoodSheet(this.s, this.consumed, this.target, {super.key});
  @override
  State<_FoodSheet> createState() => _FoodSheetState();
}

class _FoodSheetState extends State<_FoodSheet> {
  void openCustom() {
    nameCtl.text = q;
    setState(() => customOpen = true);
  }

  String q = '';
  Food? pick;
  double qty = 1;
  bool customOpen = false;
  final nameCtl = TextEditingController();
  final kcalCtl = TextEditingController();

  @override
  void dispose() {
    nameCtl.dispose();
    kcalCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    if (customOpen) {
      final kc = int.tryParse(kcalCtl.text) ?? 0;
      return Padding(
        padding: _pad,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add your own', style: _title(c)),
          const SizedBox(height: 16),
          const Label('What is it'),
          const SizedBox(height: 8),
          TextField(
              controller: nameCtl,
              decoration: _dec(c, "Amma's sambar"),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          const Label('Calories in one serving'),
          const SizedBox(height: 8),
          TextField(
            controller: kcalCtl,
            keyboardType: TextInputType.number,
            style: mono(c, size: 14),
            decoration: _dec(c, '160'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'Saved for reuse, so next time it is one tap. A rough number you use every '
            'time beats an exact number you re-guess — re-guessing biases the expenditure '
            'measurement.',
            style: sans(c, size: 12, color: c.ink3),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: SecondaryButton('Back', onTap: () => setState(() => customOpen = false))),
            const SizedBox(width: 9),
            Expanded(
              child: PrimaryButton('Save and add',
                  onTap: nameCtl.text.trim().isEmpty || kc <= 0
                      ? null
                      : () {
                          widget.s.addCustomFood(nameCtl.text, kc);
                          Navigator.pop(context);
                        }),
            ),
          ]),
        ]),
      );
    }

    if (pick != null) {
      final kcal = (pick!.k * qty).round();
      final after = widget.consumed + kcal;
      return Padding(
        padding: _pad,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(pick!.n, style: _title(c))),
            Num(mealFor(minutesOfDay(DateTime.now())).label.toUpperCase(),
                size: 11, color: c.ink3),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Pill('−',
                semanticLabel: 'Less',
                onTap: () =>
                    setState(() => qty = math.max(0.5, qty <= 2 ? qty - 0.5 : qty - 1))),
            Expanded(
              child: Column(children: [
                Num(qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1),
                    size: 20),
                Text('× ${pick!.u}', style: sans(c, size: 11.5, color: c.ink3)),
              ]),
            ),
            Pill('+',
                semanticLabel: 'More',
                onTap: () =>
                    setState(() => qty = math.min(20, qty < 2 ? qty + 0.5 : qty + 1))),
          ]),
          const SizedBox(height: 16),
          // Show where this lands before committing, so the decision is informed rather
          // than something you check afterwards and regret.
          Container(
            padding: const EdgeInsets.all(13),
            decoration:
                BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Adding', style: sans(c)),
                Num('$kcal kcal', size: 17),
              ]),
              if (widget.target != null) ...[
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: 'Takes you to ', style: sans(c, size: 12)),
                    TextSpan(text: '$after', style: mono(c, size: 12)),
                    TextSpan(text: ' of ', style: sans(c, size: 12)),
                    TextSpan(
                        text: widget.target!.round().toString(), style: mono(c, size: 12)),
                  ])),
                  Text(
                    after > widget.target!
                        ? 'over by ${after - widget.target!.round()}'
                        : '${widget.target!.round() - after} left',
                    style: sans(c,
                        size: 12, color: after > widget.target! ? c.warn : c.ink2),
                  ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: SecondaryButton('Back', onTap: () => setState(() => pick = null))),
            const SizedBox(width: 9),
            Expanded(
              child: PrimaryButton('Add $kcal kcal', onTap: () {
                widget.s.addEntry(pick!, qty);
                Navigator.pop(context);
              }),
            ),
          ]),
        ]),
      );
    }

    final groups = q.trim().isEmpty
        ? browseGroups(widget.s.recents, widget.s.customFoods)
        : [
            FoodGroup(
              'matches, lightest first',
              searchFoods(q, widget.s.recents, widget.s.customFoods),
            )
          ];

    return Padding(
      padding: _pad,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add food', style: _title(c)),
        const SizedBox(height: 12),
        TextField(
          decoration: _dec(c, 'Search dal, roti, coffee…'),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 12),
        for (final g in groups) ...[
          Label(g.label),
          const SizedBox(height: 4),
          for (final f in g.items)
            InkWell(
              onTap: () => setState(() {
                pick = f;
                qty = 1;
              }),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.n, style: TextStyle(fontSize: 13.5, color: c.ink)),
                      Text(f.u, style: sans(c, size: 11.5, color: c.ink3)),
                    ]),
                  ),
                  Num('${f.k}', size: 12.5, color: c.ink2),
                ]),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------ routine editor

Future<void> showRoutineSheet(BuildContext context, Store s, Routine r, bool isNew) =>
    showAppSheet(context, (ctx) => _RoutineSheet(s, r, isNew));

class _RoutineSheet extends StatefulWidget {
  final Store s;
  final Routine r;
  final bool isNew;
  const _RoutineSheet(this.s, this.r, this.isNew);
  @override
  State<_RoutineSheet> createState() => _RoutineSheetState();
}

class _RoutineSheetState extends State<_RoutineSheet> {
  late Routine d = widget.r;
  late final nameCtl = TextEditingController(text: d.name);
  late final msgCtl = TextEditingController(text: d.message);

  @override
  void dispose() {
    nameCtl.dispose();
    msgCtl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int i) async {
    final cur = minsOf(d.times[i]);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (t == null) return;
    setState(() {
      final times = [...d.times];
      times[i] = clockOf(t.hour * 60 + t.minute);
      times.sort();
      d = d.copyWith(times: times);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final report = widget.s.report();
    final wTarget = report.water.targetMl ?? waterTargetMl(70);
    final delivers = d.times.length * d.amountMl;
    final dense = d.times.length > 6;

    return Padding(
      padding: _pad,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.isNew ? 'New routine' : 'Edit routine', style: _title(c)),
        const SizedBox(height: 16),

        const Label('Type'),
        const SizedBox(height: 8),
        SegControl<RoutineType>(
          value: d.type,
          // Create mode loads the template whole; edit mode changes only the type, so an
          // existing schedule is never silently overwritten.
          onChanged: (t) => setState(() {
            if (widget.isNew) {
              final fresh = widget.s.newRoutine(t);
              d = fresh.copyWith();
              nameCtl.text = fresh.name;
              msgCtl.text = fresh.message;
            } else {
              d = d.copyWith(type: t);
            }
          }),
          options: RoutineType.values.map((t) => (t, t.label)).toList(),
        ),
        if (widget.isNew) ...[
          const SizedBox(height: 8),
          Text('Picking a type fills in a ready-made schedule. Change anything below.',
              style: sans(c, size: 12, color: c.ink3)),
        ],
        const SizedBox(height: 16),

        const Label('Name'),
        const SizedBox(height: 8),
        TextField(
          controller: nameCtl,
          decoration: _dec(c, '${d.type.label} reminder'),
          onChanged: (v) => d = d.copyWith(name: v),
        ),
        const SizedBox(height: 16),

        const Label('Remind me at'),
        const SizedBox(height: 8),
        for (var i = 0; i < d.times.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              Expanded(child: Pill(ampm(d.times[i]), monoFont: true, onTap: () => _pickTime(i))),
              if (d.times.length > 1) ...[
                const SizedBox(width: 8),
                Pill('×',
                    semanticLabel: 'Remove the ${ampm(d.times[i])} reminder',
                    onTap: () => setState(() => d = d.copyWith(
                        times: [...d.times]..removeAt(i)))),
              ],
            ]),
          ),
        Pill('+ Add another time',
            tone: c.accent,
            onTap: () => setState(() {
                  final last = d.times.isEmpty ? '09:00' : d.times.last;
                  d = d.copyWith(
                      times: [...d.times, clockOf(math.min(1380, minsOf(last) + 120))]
                        ..sort());
                })),
        const SizedBox(height: 16),

        const Label('Days'),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 7; i++) ...[
            Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  final days = [...d.days];
                  if (days.contains(i)) {
                    if (days.length > 1) days.remove(i);
                  } else {
                    days
                      ..add(i)
                      ..sort();
                  }
                  d = d.copyWith(days: days);
                }),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: d.days.contains(i) ? c.accent : c.line),
                    color: d.days.contains(i) ? c.accentSoft : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(dowInitial[i],
                      style: mono(c,
                          size: 11, color: d.days.contains(i) ? c.accent : c.ink3)),
                ),
              ),
            ),
            if (i != 6) const SizedBox(width: 5),
          ],
        ]),

        if (d.type == RoutineType.water) ...[
          const SizedBox(height: 16),
          const Label('Each reminder logs'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: '${d.amountMl}'),
                keyboardType: TextInputType.number,
                style: mono(c, size: 14),
                decoration: _dec(c, '500'),
                onSubmitted: (v) =>
                    setState(() => d = d.copyWith(amountMl: int.tryParse(v) ?? 500)),
              ),
            ),
            const SizedBox(width: 9),
            Text('ml, added to Today', style: sans(c, size: 13, color: c.ink3)),
          ]),
          const SizedBox(height: 8),
          // A schedule that quietly under-delivers is worse than no schedule, because the
          // user believes hydration is handled and stops thinking about it.
          Notice(
            delivers >= wTarget
                ? '${d.times.length} × ${d.amountMl} ml is ${(delivers / 1000).toStringAsFixed(2)} L '
                    'a day — covers your ${(wTarget / 1000).toStringAsFixed(2)} L recommended intake.'
                : '${d.times.length} × ${d.amountMl} ml is only ${(delivers / 1000).toStringAsFixed(2)} L '
                    'a day, ${(delivers / wTarget * 100).round()}% of your '
                    '${(wTarget / 1000).toStringAsFixed(2)} L recommended intake. You would still need '
                    '${((wTarget - delivers) / 1000).toStringAsFixed(2)} L by hand — add a time, or '
                    'raise the amount.',
            tone: delivers >= wTarget ? 'accent' : 'warn',
          ),
        ],

        const SizedBox(height: 16),
        const Label('Notification text'),
        const SizedBox(height: 8),
        TextField(
          controller: msgCtl,
          decoration: _dec(c, 'Your own words'),
          onChanged: (v) => d = d.copyWith(message: v),
        ),

        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${d.times.length}', style: mono(c, size: 12.5, color: dense ? c.warn : c.ink)),
            TextSpan(text: ' a day, ', style: sans(c, size: 12.5, color: dense ? c.warn : c.ink2)),
            TextSpan(text: '${perWeek(d)}', style: mono(c, size: 12.5, color: dense ? c.warn : c.ink)),
            TextSpan(
              text: dense
                  ? ' a week — dense enough that people usually mute it.'
                  : ' a week.',
              style: sans(c, size: 12.5, color: dense ? c.warn : c.ink2),
            ),
          ]),
        ),

        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: SecondaryButton('Cancel', onTap: () => Navigator.pop(context))),
          const SizedBox(width: 9),
          Expanded(
            child: PrimaryButton(widget.isNew ? 'Start routine' : 'Save changes', onTap: () {
              widget.s.upsertRoutine(d.copyWith(
                name: nameCtl.text.trim().isEmpty
                    ? '${d.type.label} reminder'
                    : nameCtl.text.trim(),
                message: msgCtl.text.trim().isEmpty ? 'Time for this.' : msgCtl.text.trim(),
                done: d.done.where(d.times.contains).toList(),
              ));
              Navigator.pop(context);
            }),
          ),
        ]),
        if (!widget.isNew) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () {
                widget.s.deleteRoutine(d.id);
                Navigator.pop(context);
              },
              child: Text('Delete this routine',
                  style: TextStyle(color: c.warn, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ settings

Future<void> showSettingsSheet(BuildContext context, Store s) => showAppSheet(
      context,
      (ctx) => _SettingsSheet(s),
      // Pinned. `showAppSheet` already provides the scroll view, so Done must not live
      // inside the scrolling content — settings is long enough that it would sit below
      // the fold on every phone.
      footer: (ctx) => PrimaryButton('Done', onTap: () => Navigator.pop(ctx)),
    );

class _SettingsSheet extends StatefulWidget {
  final Store s;
  const _SettingsSheet(this.s);
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _height =
      TextEditingController(text: widget.s.profile.heightCm.round().toString());
  late final TextEditingController _born =
      TextEditingController(text: widget.s.profile.birthYear.toString());

  @override
  void dispose() {
    _height.dispose();
    _born.dispose();
    super.dispose();
  }

  /// Each group is its own panel with its own explanation.
  ///
  /// It used to be one flat column of controls 16px apart, which made three unrelated
  /// decisions look like one list — and a setting that changes your calorie target
  /// should not be indistinguishable from a theme toggle.
  Widget _group(Palette c, String title, String info, List<Widget> children) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Label(title),
          const SizedBox(height: 4),
          Text(info, style: sans(c, size: 12, color: c.ink3)),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Future<void> _pickQuiet(bool from) async {
    final cur = minsOf(from ? widget.s.quietFrom : widget.s.quietTo);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (t == null) return;
    setState(() => widget.s.setQuietHours(
          from: from ? clockOf(t.hour * 60 + t.minute) : null,
          to: from ? null : clockOf(t.hour * 60 + t.minute),
        ));
  }

  Future<void> _confirmErase() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
            'Every weigh-in, food entry and routine on this phone. There is no account '
            'and no backup, so this cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.s.eraseAll();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final s = widget.s;
    final report = s.report();
    final kg = report.weight.trend ?? 75;
    final age = DateTime.now().year - s.profile.birthYear;
    final t = intakeTarget(s.profile, report.energy.tdee.kcal, kg, age);

    final goalKind = switch (s.profile.goal) {
      LoseGoal() => 'lose',
      GainGoal() => 'gain',
      MaintainGoal() => 'maintain',
    };
    final rate = switch (s.profile.goal) {
      LoseGoal(kgPerWeek: final r) => r,
      GainGoal(kgPerWeek: final r) => r,
      MaintainGoal() => 0.5,
    };

    return Padding(
      padding: _pad,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Settings', style: _title(c)),
        const SizedBox(height: 14),
            _group(c, 'Appearance',
                'Auto follows whatever your phone is set to, and changes with it through '
                'the day.', [
              SegControl<ThemeChoice>(
                value: s.theme,
                onChanged: (v) => setState(() => s.setTheme(v)),
                options: const [
                  (ThemeChoice.light, 'Light'),
                  (ThemeChoice.dark, 'Dark'),
                  (ThemeChoice.auto, 'Auto'),
                ],
              ),
            ]),
            const SizedBox(height: 12),

            _group(c, 'About you',
                'Height and age feed the starting formula, and age also shapes the safety '
                'floor under your target. Nothing else uses them.', [
              Row(children: [
                Expanded(
                  child: _field(c, 'Height', TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: _dec(c, 'Height').copyWith(suffixText: 'cm'),
                    onChanged: (v) {
                      final n = double.tryParse(v);
                      if (n != null && n >= 120 && n <= 230) {
                        s.setProfile(s.profile.copyWith(heightCm: n));
                      }
                    },
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(c, 'Year of birth', TextField(
                    controller: _born,
                    keyboardType: TextInputType.number,
                    decoration: _dec(c, 'Born').copyWith(suffixText: 'year'),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      final thisYear = DateTime.now().year;
                      if (n != null && n >= thisYear - 100 && n <= thisYear - 13) {
                        s.setProfile(s.profile.copyWith(birthYear: n));
                      }
                    },
                  )),
                ),
              ]),
              const SizedBox(height: 8),
              Text('$age years old', style: sans(c, size: 12, color: c.ink3)),
            ]),
            const SizedBox(height: 12),

            _group(c, 'Goal',
                'The rate sets how big a daily deficit TrueBurn aims for. Faster is not '
                'better — past about 1% of body weight a week, more of the loss is '
                'muscle.', [
              SegControl<String>(
                value: goalKind,
                onChanged: (v) => setState(() => s.setProfile(s.profile.copyWith(
                    goal: v == 'maintain'
                        ? const MaintainGoal()
                        : v == 'gain'
                            ? GainGoal(rate)
                            : LoseGoal(rate)))),
                options: const [('lose', 'Lose'), ('maintain', 'Maintain'), ('gain', 'Gain')],
              ),
              if (goalKind != 'maintain') ...[
                const SizedBox(height: 10),
                SegControl<double>(
                  value: rate,
                  onChanged: (v) => setState(() => s.setProfile(s.profile.copyWith(
                      goal: goalKind == 'gain' ? GainGoal(v) : LoseGoal(v)))),
                  options: const [
                    (0.25, '0.25 kg'),
                    (0.5, '0.5 kg'),
                    (0.75, '0.75 kg'),
                    (1.0, '1.0 kg'),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Notice(
                'Your daily target is ${t.kcal?.round() ?? '—'} kcal — measured expenditure '
                '${report.energy.tdee.kcal.round()} minus the deficit for this goal.',
                tone: 'accent',
              ),
              for (final w in t.warnings) ...[
                const SizedBox(height: 8),
                Notice(w, tone: 'warn'),
              ],
            ]),
            const SizedBox(height: 12),

            _group(c, 'Starting estimate',
                'These only shape the first three weeks. Once TrueBurn has enough '
                'weigh-ins it measures your expenditure directly and stops using them. '
                'Pick the basal formula that fits you rather than having one inferred.', [
              SegControl<FormulaVariant>(
                value: s.profile.formulaVariant,
                onChanged: (v) =>
                    setState(() => s.setProfile(s.profile.copyWith(formulaVariant: v))),
                options: const [
                  (FormulaVariant.mifflinMale, 'Formula A'),
                  (FormulaVariant.mifflinFemale, 'Formula B'),
                ],
              ),
              const SizedBox(height: 10),
              SegControl<ActivityLevel>(
                value: s.profile.activityLevel,
                onChanged: (v) =>
                    setState(() => s.setProfile(s.profile.copyWith(activityLevel: v))),
                options: const [
                  (ActivityLevel.sedentary, 'Sed.'),
                  (ActivityLevel.light, 'Light'),
                  (ActivityLevel.moderate, 'Mod.'),
                  (ActivityLevel.active, 'Active'),
                ],
              ),
            ]),
            const SizedBox(height: 12),

            _group(c, 'Quiet hours',
                'Reminders inside this window are moved rather than silenced — a routine '
                'you asked for should not vanish because it fell at a bad hour.', [
              Row(children: [
                Expanded(child: _timeField(c, 'From', s.quietFrom, () => _pickQuiet(true))),
                const SizedBox(width: 10),
                Expanded(child: _timeField(c, 'To', s.quietTo, () => _pickQuiet(false))),
              ]),
            ]),
            const SizedBox(height: 12),

            _group(c, 'Your data',
                'Everything stays on this phone. There is no account, nothing is '
                'uploaded, and nothing leaves the device.', [
              SecondaryButton('Delete all data', onTap: _confirmErase),
            ]),
      ]),
    );
  }

  Widget _field(Palette c, String label, Widget child) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: labelStyle(c)),
        const SizedBox(height: 6),
        child,
      ]);

  Widget _timeField(Palette c, String label, String value, VoidCallback onTap) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: labelStyle(c)),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: c.sunken,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Num(ampm(value), size: 13.5, color: c.ink),
            ),
          ),
        ),
      ]);
}

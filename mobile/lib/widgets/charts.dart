/// The four pieces of information design: water fill, weight trend, adherence timeline,
/// meal-grouped intake. All CustomPainter — Flutter's strongest suit, and the reason
/// these read better here than they did in SVG.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/weight_trend.dart';
import '../domain/foods.dart';
import '../theme.dart';

// --------------------------------------------------------------------- water

/// The level *is* the reading, so the motion carries information rather than
/// decorating. The level eases toward its new value so adding water reads as filling.
/// No text sits on top: over a variable fill no single ink colour stays legible, so the
/// readout lives on solid surface below (§5.5).
class WaterWave extends StatefulWidget {
  final double pct;
  final double height;
  const WaterWave({super.key, required this.pct, this.height = 76});

  @override
  State<WaterWave> createState() => _WaterWaveState();
}

class _WaterWaveState extends State<WaterWave> with TickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  late double _shown = widget.pct;
  double _from = 0;
  double _target = 0;
  Timer? _idle;

  late final AnimationController _level = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..addListener(() {
      setState(() =>
          _shown = _from + (_target - _from) * Curves.easeOut.transform(_level.value));
    });

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not `initState`. `_stir` reads MediaQuery for the reduced-motion setting, and an
    // inherited widget cannot be read before the first dependency resolution — doing it
    // in initState throws, but only in debug and only once the widget is actually built,
    // which is why a clean analyze and a clean profile run both missed it.
    if (!_started) {
      _started = true;
      _stir();
    }
  }

  /// Ripple, then come to rest.
  ///
  /// Looping forever meant a 60fps repaint for as long as Today was on screen — pure
  /// battery cost for decoration, and visually restless in an app whose whole posture is
  /// calm. Water that moves when you pour and settles afterwards is both cheaper and
  /// truer to the thing it depicts.
  void _stir() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _phase.repeat();
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) _phase.stop();
    });
  }

  @override
  void didUpdateWidget(WaterWave old) {
    super.didUpdateWidget(old);
    if (old.pct != widget.pct) {
      _from = _shown;
      _target = widget.pct;
      _level.forward(from: 0);
      _stir();
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    _phase.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _phase,
          builder: (_, _) => CustomPaint(
            painter: _WavePainter(
              pct: _shown,
              phase: reduced ? 0 : _phase.value * math.pi * 2,
              fill: c.accent,
              bg: c.sunken,
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double pct, phase;
  final Color fill, bg;
  const _WavePainter(
      {required this.pct, required this.phase, required this.fill, required this.bg});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    // Always draw a shallow band, even at zero. Otherwise an empty card — the state
    // every user sees on their first run — is a flat grey rectangle that reads as a
    // component which failed to render. The litre figure beside it carries the real
    // value, so a visible sliver misleads nobody.
    final shown = math.max(pct.clamp(0, 100), 4.0);
    final level = size.height - (shown / 100) * size.height;
    // Damp the swell at low fill so a nearly-empty glass does not slosh like a full one.
    final swell = math.min(1.0, shown / 15);

    void wave(double amp, double off, double opacity) {
      final p = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final y = level +
            math.sin((x / math.max(1, size.width)) * math.pi * 2.2 + phase + off) *
                amp *
                swell;
        p.lineTo(x, y);
      }
      p
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(p, Paint()..color = fill.withValues(alpha: opacity));
    }

    wave(10, 0, 0.55);
    wave(14, math.pi / 2, 0.32);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.pct != pct || old.phase != phase || old.fill != fill;
}

// --------------------------------------------------------------------- trend

/// Raw weigh-ins are scattered dots behind a confident trend line — the product's whole
/// thesis, drawn. Dots earn their place at a month, shrink at a quarter, and are dropped
/// at a year where 365 of them are texture rather than information.
class TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final int days;
  final double height;
  const TrendChart(
      {super.key, required this.points, required this.days, this.height = 92});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final slice = points.length > days ? points.sublist(points.length - days) : points;
    if (slice.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
        painter: _TrendPainter(
          slice: slice,
          showDots: days <= 90,
          dotR: days <= 30 ? 1.9 : 1.2,
          line: c.line,
          dot: c.ink3,
          accent: c.accent,
        ),
      ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> slice;
  final bool showDots;
  final double dotR;
  final Color line, dot, accent;
  const _TrendPainter({
    required this.slice,
    required this.showDots,
    required this.dotR,
    required this.line,
    required this.dot,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 7.0;
    final vals = [
      ...slice.map((p) => p.trend),
      if (showDots) ...slice.map((p) => p.raw),
    ];
    final lo = vals.reduce(math.min) - 0.25;
    final hi = vals.reduce(math.max) + 0.25;
    final span = math.max(0.1, hi - lo);

    double x(int i) => pad + (i / (slice.length - 1)) * (size.width - pad * 2);
    double y(double v) => pad + (1 - (v - lo) / span) * (size.height - pad * 2);

    final grid = Paint()..color = line;
    for (final g in [0.25, 0.5, 0.75]) {
      final gy = pad + g * (size.height - pad * 2);
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }

    if (showDots) {
      final dp = Paint()..color = dot.withValues(alpha: 0.42);
      for (var i = 0; i < slice.length; i++) {
        canvas.drawCircle(Offset(x(i), y(slice[i].raw)), dotR, dp);
      }
    }

    final path = Path();
    for (var i = 0; i < slice.length; i++) {
      final o = Offset(x(i), y(slice[i].trend));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);

    final end = Offset(x(slice.length - 1), y(slice.last.trend));
    canvas.drawCircle(
        end,
        5.4,
        Paint()
          ..color = accent.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.drawCircle(end, 3, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.slice != slice || old.accent != accent;
}

// -------------------------------------------------------------------- intake

/// Intake grouped by meal, with the remaining budget as a labelled block.
///
/// One segment per *entry* was tried first: a 16 kcal spoon of sugar became an invisible
/// sliver, and alternating accent tints coloured segments arbitrarily. Four meal blocks
/// are always legible and the opacity ramp — lighter earlier in the day — means
/// something (§5.3).
class IntakeBar extends StatelessWidget {
  final Map<Meal, int> byMeal;
  final int total;
  final int target;
  const IntakeBar(
      {super.key, required this.byMeal, required this.total, required this.target});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final over = total > target;
    final scale = math.max(math.max(total, target), 1);
    final left = math.max(0, target - total);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 32,
          color: c.sunken,
          child: Stack(children: [
            Row(children: [
              for (var i = 0; i < Meal.values.length; i++)
                if ((byMeal[Meal.values[i]] ?? 0) > 0)
                  Expanded(
                    flex: ((byMeal[Meal.values[i]] ?? 0) * 1000 ~/ scale),
                    child: Container(
                      color: c.accent.withValues(alpha: 0.58 + i * 0.14),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(Meal.values[i].label,
                            maxLines: 1,
                            style: TextStyle(
                                color: c.onAccent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              if (left > 0)
                Expanded(
                  flex: left * 1000 ~/ scale,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('$left left',
                          maxLines: 1,
                          style: mono(c, size: 10.5, color: c.ink3)),
                    ),
                  ),
                ),
            ]),
            if (over)
              Positioned(
                left: null,
                child: FractionallySizedBox(
                  widthFactor: target / scale,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(width: 2, height: 32, color: c.ink.withValues(alpha: 0.65)),
                  ),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 4, children: [
        for (final m in Meal.values)
          if ((byMeal[m] ?? 0) > 0)
            Text.rich(TextSpan(children: [
              TextSpan(text: '${m.label} ', style: TextStyle(fontSize: 11, color: c.ink3)),
              TextSpan(text: '${byMeal[m]}', style: mono(c, size: 11, color: c.ink2)),
            ])),
        Text.rich(TextSpan(children: [
          if (over) TextSpan(text: 'over by ', style: TextStyle(fontSize: 11, color: c.warn)),
          TextSpan(
              text: '${over ? total - target : left}',
              style: mono(c, size: 11, color: over ? c.warn : c.ink2)),
          if (!over) TextSpan(text: ' left', style: TextStyle(fontSize: 11, color: c.ink3)),
        ])),
      ]),
    ]);
  }
}

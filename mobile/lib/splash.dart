/// Launch screen.
///
/// Android 12+ shows a system splash that can only render a centred icon — there is no
/// slot for a byline. So the studio credit lives here, in the Flutter-drawn second
/// stage, which is the standard two-stage pattern. This also covers the hydrate and
/// notification-init work so the app never shows an empty frame.
library;


import 'package:flutter/material.dart';

import 'theme.dart';

/// The logo: scattered weigh-ins with one calm line through them.
///
/// Drawn rather than shipped as a bitmap so it stays sharp at any size and picks up the
/// palette — the same mark the launcher icon uses, and the same shape the app draws on
/// its own trend chart. The product's thesis and its logo are deliberately one picture.
class LogoMark extends StatelessWidget {
  final double size;
  final Color? color;
  const LogoMark({super.key, this.size = 96, this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter(color ?? c.accent)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final Color color;
  const _MarkPainter(this.color);

  /// Same bezier geometry as the launcher icon, so the two never drift apart.
  static const _outer = [
    [0.46, 0.00, 0.52, 0.09, 0.88, 0.28, 0.90, 0.58],
    [0.90, 0.58, 0.91, 0.83, 0.73, 0.99, 0.48, 0.99],
    [0.48, 0.99, 0.23, 0.99, 0.07, 0.83, 0.09, 0.58],
    [0.09, 0.58, 0.08, 0.40, 0.28, 0.38, 0.29, 0.22],
    [0.29, 0.22, 0.30, 0.11, 0.40, 0.06, 0.46, 0.00],
  ];
  static const _inner = [
    [0.52, 0.42, 0.58, 0.52, 0.72, 0.62, 0.70, 0.76],
    [0.70, 0.76, 0.69, 0.90, 0.58, 0.96, 0.47, 0.96],
    [0.47, 0.96, 0.35, 0.96, 0.27, 0.88, 0.28, 0.76],
    [0.28, 0.76, 0.29, 0.63, 0.46, 0.58, 0.52, 0.42],
  ];

  Path _build(List<List<double>> segs, double x0, double y0, double w, double h) {
    final p = Path()..moveTo(x0 + segs.first[0] * w, y0 + segs.first[1] * h);
    for (final s in segs) {
      p.cubicTo(x0 + s[2] * w, y0 + s[3] * h, x0 + s[4] * w, y0 + s[5] * h,
          x0 + s[6] * w, y0 + s[7] * h);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final fw = s * 0.50;
    final fx = (s - fw) / 2;
    final fy = s * 0.14;
    final fh = fw * 1.22;

    // Even-odd so the inner core punches through, giving the two-tone read that makes
    // the shape unmistakably fire rather than a leaf or a droplet.
    final flame = Path.combine(
      PathOperation.difference,
      _build(_outer, fx, fy, fw, fh),
      _build(_inner, fx, fy, fw, fh),
    );
    canvas.drawPath(flame, Paint()..color = color);

    final rw = fw * 0.86;
    final rh = s * 0.038;
    final ry = fy + fh + s * 0.060;
    canvas.drawRRect(
      RRect.fromLTRBR((s - rw) / 2, ry, (s + rw) / 2, ry + rh, Radius.circular(rh / 2)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// The splash, and the handoff into it.
///
/// There are unavoidably two screens here — the OS launch screen while the Flutter
/// engine boots, then this one — and the app used to make that obvious: the native mark
/// was a density-less bitmap the system rescaled at will, while this one drew at 108dp
/// and sat *above* centre because the wordmark below pushed it up. So the mark jumped
/// size and position, and then text appeared. Two splashes.
///
/// Now the mark is 108dp on both sides and screen-centred on both sides, so the handoff
/// is invisible. The wordmark is positioned *beneath* the centred mark rather than laid
/// out under it in a Column, which is what stops it shifting the mark when it arrives.
/// The result reads as one splash whose text fades in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    // A beat after the engine hands over, so the mark is unmistakably continuous with
    // the launch screen before anything else moves.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _showText = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    const mark = 108.0;

    Widget fade(Widget child, {double dy = 8}) => AnimatedSlide(
          offset: _showText ? Offset.zero : Offset(0, dy / 100),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _showText ? 1 : 0,
            duration: const Duration(milliseconds: 420),
            child: child,
          ),
        );

    return Scaffold(
      backgroundColor: c.ground,
      // SizedBox.expand is load-bearing: AnimatedSwitcher stacks its children under
      // loose constraints, so without it this shrink-wraps and drifts to the top-left.
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Exactly where the launch screen left it — nothing below is allowed to
            // move it.
            const LogoMark(size: mark),
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reserve the mark's own height plus its gap, so the text starts
                  // below it without the layout knowing about the mark at all.
                  const SizedBox(height: mark + 44),
                  fade(Text(
                    'TrueBurn',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: c.ink,
                    ),
                  )),
                  const SizedBox(height: 8),
                  fade(
                    Text(
                      'Measured, not estimated.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.ink3,
                        letterSpacing: 0.1,
                      ),
                    ),
                    dy: 14,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: SafeArea(
                top: false,
                child: fade(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('by', style: TextStyle(fontSize: 11, color: c.ink3)),
                      const SizedBox(height: 4),
                      // Casing matches funnudge.com exactly — capital F, capital N.
                      Text(
                        'FunNudge',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: c.ink2,
                        ),
                      ),
                    ],
                  ),
                  dy: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

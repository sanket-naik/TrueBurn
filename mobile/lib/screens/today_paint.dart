part of 'today.dart';

/// A dashed rule standing in for the trend that does not exist yet — the visual says
/// "this continues" without pretending to plot data we have not got.
class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 4, size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

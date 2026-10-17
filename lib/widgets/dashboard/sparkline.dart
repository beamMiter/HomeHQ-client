import 'package:flutter/material.dart';

import 'money.dart';

/// A few points as a thin line, with the last one marked: for a number that
/// should say which way it has been going, without an axis.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.width = 84,
    this.height = 36,
  });

  final List<double> values;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(width, height),
      painter: _SparkPainter(values),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const pad = 5.0;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    Offset at(int i) => Offset(
      pad + (size.width - pad * 2) * i / (values.length - 1),
      size.height - pad - (size.height - pad * 2) * ((values[i] - lo) / span),
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = kPacePrevColor,
    );
    // The current period in the accent, with a ring of the surface round it.
    final end = at(values.length - 1);
    canvas.drawCircle(end, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(end, 4, Paint()..color = kPaceNowColor);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values;
}

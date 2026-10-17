import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/app_colors.dart';
import 'money.dart';

/// What has been spent so far in the month, day by day, against the month
/// before: two running totals on one axis.
///
/// This month is the ink line (2 px, with a wash under it and a marked end);
/// last month is a quiet grey line. The line for this month stops at
/// [throughDay]: the days still to come are not zeros.
///
/// Touch or drag to read a day: a hairline and a dot on each line, and
/// [onTouch] says which day, so the page can print its two amounts. (The
/// readout is words on the page, never only a tooltip.)
class SpendingPaceChart extends StatelessWidget {
  const SpendingPaceChart({
    super.key,
    required this.current,
    required this.previous,
    required this.throughDay,
    required this.semanticsLabel,
    this.touchDay,
    this.onTouch,
    this.animationKey,
  });

  /// Running totals, one per day of the month and of the month before.
  final List<double> current;
  final List<double> previous;
  final int throughDay;
  final String semanticsLabel;

  /// The day being read (1-based), or null.
  final int? touchDay;
  final ValueChanged<int>? onTouch;

  /// Changes when the figures are a new set: the lines draw in again.
  final Object? animationKey;

  static const height = 176.0;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, box) {
            final days = math.max(current.length, previous.length);
            void touch(Offset p) {
              if (days < 2 || onTouch == null) return;
              final plotW =
                  box.maxWidth - _PacePainter.left - _PacePainter.right;
              final f = ((p.dx - _PacePainter.left) / plotW).clamp(0.0, 1.0);
              onTouch!((f * (days - 1)).round() + 1);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => touch(d.localPosition),
              onHorizontalDragStart: (d) => touch(d.localPosition),
              onHorizontalDragUpdate: (d) => touch(d.localPosition),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(animationKey),
                tween: Tween(begin: 0, end: 1),
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) => CustomPaint(
                  painter: _PacePainter(
                    current: current,
                    previous: previous,
                    throughDay: throughDay,
                    touchDay: touchDay,
                    progress: progress,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PacePainter extends CustomPainter {
  _PacePainter({
    required this.current,
    required this.previous,
    required this.throughDay,
    required this.touchDay,
    required this.progress,
  });

  final List<double> current;
  final List<double> previous;
  final int throughDay;
  final int? touchDay;
  final double progress;

  static const left = 38.0, right = 14.0, top = 16.0, bottom = 24.0;
  static const _grid = Color(0xFFE4E8F0);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final days = math.max(current.length, previous.length);
    final upTo = throughDay.clamp(0, current.length);
    final seen = upTo == 0 ? 0.0 : current[upTo - 1];
    final peak = math.max(seen, previous.isEmpty ? 0.0 : previous.last);
    final axisMax = niceMax(peak);

    // Hairline grid with the amounts it stands for, and the days along the foot.
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = plot.bottom - plot.height * f;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        compactBaht(axisMax * f),
        Offset(plot.left - 6, y),
        right: true,
      );
    }
    if (days < 2) return;
    double x(int day) => plot.left + plot.width * (day - 1) / (days - 1);
    double y(double v) => plot.bottom - plot.height * (v / axisMax);
    for (final d in <int>{1, 8, 15, 22, days}) {
      if (d <= days) _text(canvas, '$d', Offset(x(d), size.height - 10));
    }

    // How many points of a line are drawn so far (the lines draw in).
    int shown(int count) =>
        (count * progress).ceil().clamp(count > 0 ? 1 : 0, count);

    Path line(List<double> v, int count) {
      final p = Path()..moveTo(x(1), y(v[0]));
      for (var i = 1; i < count; i++) {
        p.lineTo(x(i + 1), y(v[i]));
      }
      return p;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Last month, whole.
    final prevN = shown(previous.length);
    if (prevN >= 2) {
      canvas.drawPath(line(previous, prevN), stroke..color = kPacePrevColor);
    }

    // This month, as far as it has got.
    final nowN = shown(upTo);
    if (nowN >= 1) {
      if (nowN >= 2) {
        final now = line(current, nowN);
        final area = Path.from(now)
          ..lineTo(x(nowN), plot.bottom)
          ..lineTo(x(1), plot.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()..color = kPaceNowColor.withValues(alpha: 0.10),
        );
        canvas.drawPath(now, stroke..color = kPaceNowColor);
      }
      // The end of the line: a dot with a ring of the surface, and its value.
      if (nowN == upTo && touchDay == null) {
        final end = Offset(x(upTo), y(current[upTo - 1]));
        _dot(canvas, end, kPaceNowColor);
        final nearTop = end.dy < plot.top + 14;
        _text(
          canvas,
          compactBaht(current[upTo - 1]),
          Offset(
            math.min(end.dx, plot.right - 6),
            end.dy + (nearTop ? 16 : -14),
          ),
          bold: true,
        );
      }
    }

    // A day being read: a hairline, and a dot on each line at that day.
    final d = touchDay;
    if (d != null && d >= 1 && d <= days) {
      canvas.drawLine(
        Offset(x(d), plot.top),
        Offset(x(d), plot.bottom),
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: 0.55)
          ..strokeWidth = 1,
      );
      if (d <= previous.length) {
        _dot(canvas, Offset(x(d), y(previous[d - 1])), kPacePrevColor);
      }
      if (d <= upTo) {
        _dot(canvas, Offset(x(d), y(current[d - 1])), kPaceNowColor);
      }
    }
  }

  /// A mark with a 2 px ring of the surface round it, so it reads where it
  /// crosses a line.
  void _dot(Canvas canvas, Offset at, Color color) {
    canvas.drawCircle(at, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(at, 4.5, Paint()..color = color);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool right = false,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          // Text wears the text tokens, never a series colour.
          color: bold ? AppColors.deepNavy : AppColors.textMuted,
          fontSize: 11,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right ? at.dx - tp.width : at.dx - tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_PacePainter old) =>
      old.current != current ||
      old.previous != previous ||
      old.throughDay != throughDay ||
      old.touchDay != touchDay ||
      old.progress != progress;
}

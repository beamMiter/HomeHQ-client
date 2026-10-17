import 'package:flutter/material.dart';

import '../../models/spending.dart';
import '../../shared/app_colors.dart';
import 'money.dart';

/// Six months of spending as stacked columns: bills below, purchases above.
///
/// Columns are thin (24 px at most) with a rounded top and a square foot, the
/// two parts of a column are 2 px apart, the grid is a hairline, and only the
/// chosen month carries its value. Tapping a column chooses that month.
class SpendingTrendChart extends StatelessWidget {
  const SpendingTrendChart({
    super.key,
    required this.points,
    required this.selected,
    required this.labels,
    required this.onSelect,
    required this.semanticsLabel,
    this.animationKey,
  });

  final List<SpendPoint> points;

  /// Index of the month on show, or -1.
  final int selected;

  /// The x-axis words, one per point.
  final List<String> labels;
  final ValueChanged<int> onSelect;
  final String semanticsLabel;

  /// Changes when the figures are a new set: the columns grow in again.
  final Object? animationKey;

  static const height = 190.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                if (points.isEmpty) return;
                final slot =
                    (box.maxWidth - _TrendPainter.left - _TrendPainter.right) /
                    points.length;
                final i = ((d.localPosition.dx - _TrendPainter.left) / slot)
                    .floor();
                if (i >= 0 && i < points.length) onSelect(i);
              },
              child: TweenAnimationBuilder<double>(
                key: ValueKey(animationKey),
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) => CustomPaint(
                  size: Size(box.maxWidth, height),
                  painter: _TrendPainter(
                    points: points,
                    selected: selected,
                    labels: labels,
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

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.selected,
    required this.labels,
    this.progress = 1,
  });

  final List<SpendPoint> points;
  final int selected;
  final List<String> labels;

  /// 0..1: how far the columns have grown.
  final double progress;

  static const left = 38.0, right = 6.0, top = 18.0, bottom = 26.0;

  static const _grid = Color(0xFFE4E8F0);
  static const _band = Color(0xFFF1F4FA);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxTotal = points.fold<double>(
      0,
      (m, p) => p.total > m ? p.total : m,
    );
    final axisMax = niceMax(maxTotal);

    // Hairline grid and the amounts they stand for: 0, half, top.
    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = plot.bottom - plot.height * f;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(
        canvas,
        compactBaht(axisMax * f),
        Offset(plot.left - 6, y),
        align: _Align.right,
      );
    }

    if (points.isEmpty) return;
    final slot = plot.width / points.length;
    final barW = slot * 0.55 > 24 ? 24.0 : slot * 0.55;
    const gap = 2.0, r = Radius.circular(4);

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = plot.left + slot * (i + 0.5);

      if (i == selected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              cx - slot / 2 + 2,
              plot.top - 6,
              cx + slot / 2 - 2,
              size.height - 2,
            ),
            const Radius.circular(8),
          ),
          Paint()..color = _band,
        );
      }

      // Bills at the foot, purchases on top; each part only as tall as its
      // share, the foot square and the head rounded.
      final billsH = plot.height * (p.bills / axisMax) * progress;
      final buyH = plot.height * (p.purchases / axisMax) * progress;
      final hasBills = p.bills > 0, hasBuy = p.purchases > 0;
      var y = plot.bottom;
      if (hasBills) {
        final h = billsH < 2 ? 2.0 : billsH;
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(
            cx - barW / 2,
            y - h,
            cx + barW / 2,
            y,
            topLeft: hasBuy ? Radius.zero : r,
            topRight: hasBuy ? Radius.zero : r,
          ),
          Paint()..color = kBillsColor,
        );
        y -= h + (hasBuy ? gap : 0);
      }
      if (hasBuy) {
        final h = buyH < 2 ? 2.0 : buyH;
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(
            cx - barW / 2,
            y - h,
            cx + barW / 2,
            y,
            topLeft: r,
            topRight: r,
          ),
          Paint()..color = kPurchasesColor,
        );
        y -= h;
      }

      // Only the chosen month says its amount.
      if (i == selected && p.total > 0 && progress > 0.85) {
        _text(canvas, compactBaht(p.total), Offset(cx, y - 8), bold: true);
      }

      _text(
        canvas,
        i < labels.length ? labels[i] : p.month,
        Offset(cx, size.height - 11),
        bold: i == selected,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    _Align align = _Align.center,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          // Text wears the text tokens, never the series colour.
          color: bold ? AppColors.deepNavy : AppColors.textMuted,
          fontSize: 11,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      _Align.center => at.dx - tp.width / 2,
      _Align.right => at.dx - tp.width,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.labels != labels ||
      old.progress != progress;
}

enum _Align { center, right }

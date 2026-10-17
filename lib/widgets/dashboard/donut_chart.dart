import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/spending.dart';
import '../../shared/app_colors.dart';
import 'money.dart';

/// A part-to-whole as a ring, for a handful of parts: each bill type in its own
/// fixed colour, the total in the middle.
///
/// The parts come in a fixed order (see [kBillTypeOrder]), not by size, so a
/// type keeps its place and its colour from month to month. A 2 px gap
/// separates touching parts. The list beside it carries the names and amounts,
/// so identity is never colour alone. Tap a part (or its row) to hold it up:
/// the others dim and the middle says that one's name and amount.
class BillTypeDonut extends StatefulWidget {
  const BillTypeDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.nameFor,
    required this.semanticsLabel,
    this.animationKey,
  });

  final List<SpendSlice> slices;
  final String centerLabel;
  final String Function(String type) nameFor;
  final String semanticsLabel;

  /// Changes when the figures are a new set: the ring sweeps in again.
  final Object? animationKey;

  /// The slices as they are drawn and listed: fixed order, an unknown type
  /// folded into "other", nothing with no money.
  static List<SpendSlice> ordered(List<SpendSlice> slices) {
    final byType = <String, SpendSlice>{};
    for (final s in slices) {
      final key = kBillTypeOrder.contains(s.key) ? s.key : 'other';
      final prev = byType[key];
      byType[key] = SpendSlice(
        key: key,
        amount: (prev?.amount ?? 0) + s.amount,
        count: (prev?.count ?? 0) + s.count,
      );
    }
    return [
      for (final k in kBillTypeOrder)
        if ((byType[k]?.amount ?? 0) > 0) byType[k]!,
    ];
  }

  @override
  State<BillTypeDonut> createState() => _BillTypeDonutState();
}

class _BillTypeDonutState extends State<BillTypeDonut> {
  static const _size = 132.0;

  /// The type being held up, or null.
  String? _held;

  void _toggle(String key) => setState(() => _held = _held == key ? null : key);

  @override
  void didUpdateWidget(BillTypeDonut old) {
    super.didUpdateWidget(old);
    // A new set of figures: nothing is held any more.
    if (old.animationKey != widget.animationKey) _held = null;
  }

  /// Which part a touch at [p] (on the ring's 132 px square) is on.
  String? _hit(Offset p, List<SpendSlice> parts, double total) {
    if (parts.isEmpty || total <= 0) return null;
    final c = const Offset(_size / 2, _size / 2);
    final d = p - c;
    final dist = d.distance;
    // The ring, with a little slack either side so a thumb finds it.
    if (dist < _size / 2 - 34 || dist > _size / 2 + 4) return null;
    var a = math.atan2(d.dy, d.dx) + math.pi / 2; // 0 at the top, clockwise
    if (a < 0) a += math.pi * 2;
    var from = 0.0;
    for (final s in parts) {
      final sweep = math.pi * 2 * (s.amount / total);
      if (a >= from && a < from + sweep) return s.key;
      from += sweep;
    }
    return parts.last.key;
  }

  @override
  Widget build(BuildContext context) {
    final parts = BillTypeDonut.ordered(widget.slices);
    final total = parts.fold<double>(0, (s, e) => s + e.amount);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final held = parts.where((p) => p.key == _held).firstOrNull;

    return Semantics(
      label: widget.semanticsLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _size,
            height: _size,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final hit = _hit(d.localPosition, parts, total);
                if (hit != null) {
                  _toggle(hit);
                } else if (_held != null) {
                  setState(() => _held = null);
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey(widget.animationKey),
                    tween: Tween(begin: 0, end: 1),
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => CustomPaint(
                      size: const Size.square(_size),
                      painter: _RingPainter(parts, total, _held, progress),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          held != null
                              ? widget.nameFor(held.key)
                              : widget.centerLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                        // The whole amount, shrunk to fit rather than rounded.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            held != null ? baht(held.amount) : baht(total),
                            key: const ValueKey('donut-center'),
                            style: const TextStyle(
                              color: AppColors.deepNavy,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (final p in parts)
                  InkWell(
                    key: ValueKey('type-${p.key}'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _toggle(p.key),
                    child: Opacity(
                      opacity: _held == null || _held == p.key ? 1 : 0.45,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: billTypeColor(p.key),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.nameFor(p.key),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  baht(p.amount),
                                  style: const TextStyle(
                                    color: AppColors.deepNavy,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${(p.amount / total * 100).round()}%',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.parts, this.total, this.held, this.progress);
  final List<SpendSlice> parts;
  final double total;
  final String? held;

  /// 0..1: how far round the ring has been drawn.
  final double progress;

  static const _stroke = 20.0;
  static const _heldStroke = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - _heldStroke / 2,
    );
    final ring = Paint()..style = PaintingStyle.stroke;

    // No parts: a quiet, empty ring rather than nothing.
    if (parts.isEmpty || total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        ring
          ..strokeWidth = _stroke
          ..color = const Color(0xFFEDF0F6),
      );
      return;
    }

    // A 2 px gap, as an angle on this ring's centre line.
    final gap = parts.length > 1 ? 2 / rect.width * 2 : 0.0;
    var start = -math.pi / 2;
    final limit = -math.pi / 2 + math.pi * 2 * progress;
    for (final p in parts) {
      final sweep = math.pi * 2 * (p.amount / total);
      final isHeld = held == p.key;
      final from = start + gap / 2;
      final to = math.min(start + sweep - gap / 2, limit);
      if (to > from) {
        var c = billTypeColor(p.key);
        if (held != null && !isHeld) c = c.withValues(alpha: 0.35);
        canvas.drawArc(
          rect,
          from,
          to - from,
          false,
          ring
            ..strokeWidth = isHeld ? _heldStroke : _stroke
            ..color = c,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.parts != parts ||
      old.total != total ||
      old.held != held ||
      old.progress != progress;
}

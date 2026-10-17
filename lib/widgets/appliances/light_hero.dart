import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'hero_frame.dart';

/// A pendant lamp, drawn, that lights the room the way the real one does:
/// the bulb glows, a cone of warm light falls from the shade to a pool on the
/// floor, and the room comes up out of the dark, all as bright as the
/// brightness says. It follows the brightness as it is dragged, and fades up
/// and down rather than snapping. Dust drifts slowly in the beam while it is
/// on; nothing moves while it is off or when the system asks for no
/// animations.
class LightHero extends StatefulWidget {
  const LightHero({
    super.key,
    required this.on,
    required this.brightness,
    required this.enabled,
    required this.onPower,
    this.offline = false,
  });

  final bool on;

  /// 1 to 100.
  final int brightness;

  /// Whether the power button can be pressed.
  final bool enabled;
  final ValueChanged<bool> onPower;
  final bool offline;

  @override
  State<LightHero> createState() => _LightHeroState();
}

class _LightHeroState extends State<LightHero>
    with SingleTickerProviderStateMixin {
  late final HeroClock _clock = HeroClock(this);
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _clock.run(widget.on && !_reduceMotion);
  }

  @override
  void didUpdateWidget(LightHero old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) _clock.run(widget.on && !_reduceMotion);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// How much light there is, 0..1: brightness reads as roughly even steps
  /// to the eye, not as watts.
  double get _target =>
      widget.on ? math.sqrt(widget.brightness.clamp(1, 100) / 100) : 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = widget.on
        ? l10n.applLightOn('${widget.brightness.clamp(1, 100)}%')
        : l10n.applLightOff;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: _target),
      duration: _reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, level, _) => ApplianceHeroFrame(
        label: label,
        top: Color.lerp(_LightPainter.nightTop, _LightPainter.litTop, level)!,
        bottom: Color.lerp(
          _LightPainter.nightFloor,
          _LightPainter.litFloor,
          math.pow(level, 0.8).toDouble(),
        )!,
        buttonAccent: const Color(0xFFD98E04),
        on: widget.on,
        enabled: widget.enabled,
        onPower: widget.onPower,
        offline: widget.offline,
        scene: CustomPaint(
          painter: _LightPainter(clock: _clock, level: level),
        ),
      ),
    );
  }
}

class _LightPainter extends CustomPainter {
  _LightPainter({required this.clock, required this.level})
    : super(repaint: clock);

  final HeroClock clock;

  /// 0 = dark, 1 = full brightness.
  final double level;

  static const nightTop = Color(0xFF151B29);
  static const nightFloor = Color(0xFF2A3348);
  static const litTop = Color(0xFF4A3B26);
  static const litFloor = Color(0xFFF7E6C4);

  /// The light's own colour: a warm white.
  static const _warm = Color(0xFFFFE0A0);
  static const _hot = Color(0xFFFFF7E2);

  static const _goldenRatio = 0.6180339887;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final rimY = h * 0.38, rimHalf = w * 0.19, rimDepth = h * 0.028;
    final shadeTop = h * 0.20, neckHalf = w * 0.045;
    final floorY = h * 0.93;

    // The light: a cone from the shade to the floor, softest at its edges,
    // a pool where it lands, and the dust that drifts in it.
    if (level > 0.001) {
      for (final (spread, alpha) in const [
        (1.0, 0.16),
        (0.82, 0.16),
        (0.62, 0.18),
      ]) {
        final half = rimHalf + (w * 0.62 - rimHalf) * spread;
        final cone = Path()
          ..moveTo(cx - rimHalf * 0.96, rimY)
          ..lineTo(cx + rimHalf * 0.96, rimY)
          ..lineTo(cx + half, floorY)
          ..lineTo(cx - half, floorY)
          ..close();
        canvas.drawPath(
          cone,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(cx, rimY),
              Offset(cx, floorY),
              [
                _warm.withValues(alpha: alpha * level * 1.6),
                _warm.withValues(alpha: alpha * level * 0.5),
                _warm.withValues(alpha: 0),
              ],
              const [0, 0.6, 1],
            ),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, floorY - h * 0.02),
          width: w * 0.95,
          height: h * 0.16,
        ),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, floorY - h * 0.02),
            w * 0.48,
            [
              _hot.withValues(alpha: 0.55 * level),
              _warm.withValues(alpha: 0.18 * level),
              _warm.withValues(alpha: 0),
            ],
            const [0, 0.5, 1],
            TileMode.clamp,
            // An ellipse, not a circle: the floor seen at a slant.
            (Matrix4.identity()
                  ..translateByDouble(cx, floorY - h * 0.02, 0, 1)
                  ..scaleByDouble(1, 0.17, 1, 1)
                  ..translateByDouble(-cx, -(floorY - h * 0.02), 0, 1))
                .storage,
          ),
      );
      _dust(canvas, size, cx, rimY, rimHalf, floorY);
    }

    // The cord and the canopy it hangs from.
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, shadeTop),
      Paint()
        ..color = const Color(0xFF0F131C)
        ..strokeWidth = 1.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(cx, 2), width: w * 0.12, height: 10),
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      ),
      Paint()
        ..color = Color.lerp(
          const Color(0xFF2B3243),
          const Color(0xFF5A4A30),
          level,
        )!,
    );

    // The glow round the bulb, under the shade.
    final bulb = Offset(cx, rimY + rimDepth * 0.2);
    final bulbR = w * 0.036;
    if (level > 0.001) {
      canvas.drawCircle(
        bulb,
        bulbR * 6,
        Paint()
          ..color = _warm.withValues(alpha: 0.35 * level)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bulbR * 3.5),
      );
    }

    // The shade: a matte dome, lit a little from the room's side and from
    // its own bulb along the rim.
    final shade = Path()
      ..moveTo(cx - neckHalf, shadeTop)
      ..cubicTo(
        cx - neckHalf * 1.4,
        shadeTop + (rimY - shadeTop) * 0.55,
        cx - rimHalf * 0.98,
        rimY - (rimY - shadeTop) * 0.35,
        cx - rimHalf,
        rimY,
      )
      ..lineTo(cx + rimHalf, rimY)
      ..cubicTo(
        cx + rimHalf * 0.98,
        rimY - (rimY - shadeTop) * 0.35,
        cx + neckHalf * 1.4,
        shadeTop + (rimY - shadeTop) * 0.55,
        cx + neckHalf,
        shadeTop,
      )
      ..close();
    final shadeBox = Rect.fromLTRB(cx - rimHalf, shadeTop, cx + rimHalf, rimY);
    canvas.drawPath(
      shade,
      Paint()
        ..shader = ui.Gradient.linear(
          shadeBox.centerLeft,
          shadeBox.centerRight,
          [
            Color.lerp(
              const Color(0xFF3A4252),
              const Color(0xFF6B5B44),
              level,
            )!,
            const Color(0xFF262C38),
            const Color(0xFF161A22),
          ],
          const [0, 0.55, 1],
        ),
    );
    // A highlight down the shade's shoulder, and its rolled rim.
    canvas.drawPath(
      shade,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - rimHalf * 0.6, shadeTop),
          Offset(cx - rimHalf * 0.2, rimY),
          [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
        ),
    );
    final rim = Rect.fromCenter(
      center: Offset(cx, rimY),
      width: rimHalf * 2,
      height: rimDepth * 2,
    );
    // Inside the shade: dark when off, glowing round the bulb when on.
    canvas.drawOval(
      rim,
      Paint()
        ..shader = ui.Gradient.radial(rim.center, rimHalf, [
          Color.lerp(const Color(0xFF39414F), _hot, level)!,
          Color.lerp(const Color(0xFF1C212B), _warm, level * 0.85)!,
        ]),
    );
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Color.lerp(
          const Color(0xFF4A5366),
          const Color(0xFFFFD48A),
          level,
        )!,
    );

    // The bulb itself, peeking out of the shade.
    if (level > 0.001) {
      canvas.drawCircle(
        bulb,
        bulbR * 1.6,
        Paint()
          ..color = _hot.withValues(alpha: 0.8 * level)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bulbR * 0.7),
      );
    }
    canvas.drawCircle(
      bulb,
      bulbR,
      Paint()
        ..shader = ui.Gradient.radial(
          bulb.translate(-bulbR * 0.3, -bulbR * 0.3),
          bulbR * 1.2,
          [
            Color.lerp(const Color(0xFFE6E9EF), Colors.white, level)!,
            Color.lerp(const Color(0xFF9AA2B1), _warm, level)!,
          ],
        ),
    );
  }

  /// Dust in the beam: tiny bright specks drifting slowly, only where the
  /// light is.
  void _dust(
    Canvas canvas,
    Size size,
    double cx,
    double rimY,
    double rimHalf,
    double floorY,
  ) {
    final t = clock.seconds;
    const n = 22;
    for (var i = 0; i < n; i++) {
      final a = (i * _goldenRatio) % 1.0;
      final b = (i * 0.7548776662 + 0.37) % 1.0;
      // Down the beam, slowly, and round again.
      final v = (b + t * (0.012 + 0.010 * a)) % 1.0;
      final y = rimY + (floorY - rimY) * (0.08 + 0.84 * v);
      final half =
          rimHalf +
          (size.width * 0.5 - rimHalf) * ((y - rimY) / (floorY - rimY));
      final x =
          cx + half * 0.85 * (2 * a - 1) + math.sin(t * 0.6 + i * 1.7) * 4;
      final edge = math.sin(math.pi * v);
      final twinkle = 0.55 + 0.45 * math.sin(t * 1.3 + i * 2.1);
      final alpha = (level * 0.75 * edge * twinkle).clamp(0.0, 1.0);
      if (alpha < 0.02) continue;
      canvas.drawCircle(
        Offset(x, y),
        0.7 + 1.0 * a,
        Paint()..color = _hot.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_LightPainter old) => old.level != level;
}

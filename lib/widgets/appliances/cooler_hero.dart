import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'air_flow.dart';
import 'hero_frame.dart';

/// A portable evaporative air cooler, drawn: a standing cabinet with its
/// control panel, the outlet and its louvers, and the water tank below.
///
/// Switched on, air leaves the outlet to both sides (the same moving air as
/// the air conditioner's). With swing the louvers turn left and right and the
/// air leans the way they point; with cooling on, the air is cool and misty
/// and bubbles rise in the tank as the pump runs. The fan speed (1 to 3) sets
/// how fast it goes, "natural" makes it come in gusts, and "sleep" makes it
/// gentle and the room dim. Changes ease in; switching on sends a first gust.
/// Nothing runs while it is off, and nothing moves when the system asks for
/// no animations.
class CoolerHero extends StatefulWidget {
  const CoolerHero({
    super.key,
    required this.on,
    required this.speed,
    required this.swing,
    required this.cooling,
    required this.mode,
    required this.enabled,
    required this.onPower,
    this.offline = false,
  });

  final bool on;

  /// 1 to 3.
  final int speed;
  final bool swing;

  /// The water pump: cool, misty air.
  final bool cooling;

  /// 'normal', 'natural' or 'sleep'.
  final String mode;

  /// Whether the power button can be pressed.
  final bool enabled;
  final ValueChanged<bool> onPower;
  final bool offline;

  @override
  State<CoolerHero> createState() => _CoolerHeroState();
}

class _CoolerHeroState extends State<CoolerHero>
    with SingleTickerProviderStateMixin {
  late final _CoolerClock _clock = _CoolerClock(this, () => widget);
  bool _reduceMotion = false;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _clock
      ..speed = _CoolerClock.speedFor(widget.speed, widget.mode)
      ..swing = widget.swing ? 1 : 0;
    loadAirShader().then((program) {
      if (!mounted || program == null) return;
      setState(() => _shader = program.fragmentShader());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _clock.front = _CoolerClock.fullFront;
    _clock.run(widget.on && !_reduceMotion);
  }

  @override
  void didUpdateWidget(CoolerHero old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) {
      if (widget.on && !_reduceMotion) {
        _clock
          ..speed = 0
          ..front = 0;
      }
      _clock.run(widget.on && !_reduceMotion);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final speed = widget.speed.clamp(1, 3);
    final label = !widget.on
        ? l10n.applCoolerOff
        : widget.cooling
        ? l10n.applCoolerOnCooling(speed)
        : l10n.applCoolerOn(speed);
    final room = _Room.of(widget.on, widget.cooling, widget.mode);

    return ApplianceHeroFrame(
      label: label,
      top: room.top,
      bottom: room.bottom,
      buttonAccent: room.button,
      on: widget.on,
      enabled: widget.enabled,
      onPower: widget.onPower,
      offline: widget.offline,
      scene: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.on ? 1.0 : 0.0),
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        builder: (context, power, _) => CustomPaint(
          painter: _CoolerPainter(
            clock: _clock,
            shader: _shader,
            power: power,
            on: widget.on,
            speed: speed,
            cooling: widget.cooling,
            mode: widget.mode,
            room: room.bottom,
          ),
        ),
      ),
    );
  }
}

/// The room's colours: cool blue while it cools, plain slate as a fan, a
/// darker night for sleep, grey and quiet while off.
class _Room {
  const _Room(this.top, this.bottom, this.button);
  final Color top, bottom, button;

  static _Room of(bool on, bool cooling, String mode) {
    if (!on) {
      return const _Room(
        Color(0xFFF1F4FA),
        Color(0xFFDDE3EE),
        Color(0xFF64748B),
      );
    }
    if (mode == 'sleep') {
      return const _Room(
        Color(0xFF141C36),
        Color(0xFF3B4B78),
        Color(0xFF3B4B78),
      );
    }
    return cooling
        ? const _Room(Color(0xFF0B4566), Color(0xFF35A7D3), Color(0xFF1C86B5))
        : const _Room(Color(0xFF334155), Color(0xFF8EA3C2), Color(0xFF5B6E8C));
  }
}

/// Everything that moves in the drawing, eased so a change never jumps.
class _CoolerClock extends HeroClock {
  _CoolerClock(super.vsync, this._widget);

  final CoolerHero Function() _widget;

  /// How far the air has travelled, in the shader's flow units.
  double flow = 0;

  /// Flow units a second; eases towards the setting's.
  double speed = 0;

  /// The louvers' sweep, in radians, and how much they swing (0..1).
  double sweep = 0;
  double swing = 0;

  /// How far (0..[fullFront]) the first gust has got since switching on.
  double front = fullFront;
  static const fullFront = 1.25;

  static double speedFor(int speed, String mode) =>
      (0.24 + 0.14 * speed.clamp(1, 3)) * (mode == 'sleep' ? 0.65 : 1);

  @override
  void advance(double dt) {
    final w = _widget();
    final ease = 1 - math.exp(-dt * 2.5);
    var target = speedFor(w.speed, w.mode);
    if (w.mode == 'natural') {
      // Natural wind: it rises and falls, never quite the same twice.
      target *=
          0.75 +
          0.25 * math.sin(seconds * 0.9) * math.sin(seconds * 0.37 + 1.3);
    }
    speed += (target - speed) * ease;
    flow += dt * speed;
    swing += ((w.swing ? 1.0 : 0.0) - swing) * ease;
    if (swing > 0.001) sweep += dt * 2 * math.pi / 5;
    if (w.on) front = math.min(front + dt / 1.1, fullFront);
  }
}

class _CoolerPainter extends CustomPainter {
  _CoolerPainter({
    required this.clock,
    required this.shader,
    required this.power,
    required this.on,
    required this.speed,
    required this.cooling,
    required this.mode,
    required this.room,
  }) : super(repaint: clock);

  final _CoolerClock clock;
  final ui.FragmentShader? shader;

  /// 0 = off, 1 = running: the lights and the air come up with it.
  final double power;
  final bool on;
  final int speed;
  final bool cooling;
  final String mode;
  final Color room;

  static const _slate = Color(0xFF475569);
  static const _cool = Color(0xFF7FD6F5);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cw = h * 0.30, ch = h * 0.66;
    final left = (w - cw) / 2, top = h * 0.05;
    final right = left + cw, bottom = top + ch;
    double ux(double f) => left + cw * f;
    double uy(double f) => top + ch * f;

    // Where the louvers point: -1 left .. 1 right.
    final aim = math.sin(clock.sweep) * clock.swing;
    final outlet = RRect.fromLTRBR(
      ux(0.14),
      uy(0.17),
      ux(0.86),
      uy(0.50),
      Radius.circular(cw * 0.06),
    );

    // Its shadow on the floor, and the floor's edge behind it.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, bottom + h * 0.035),
        width: cw * 1.5,
        height: h * 0.05,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.015),
    );

    // The air, behind the cabinet: out of the outlet to either side.
    if (power > 0.02) _air(canvas, outlet.outerRect, aim, w);

    _cabinet(canvas, Rect.fromLTRB(left, top, right, bottom), cw);
    _panel(canvas, ux, uy, cw);
    _outletAndLouvers(canvas, outlet, aim);
    _tank(
      canvas,
      RRect.fromLTRBR(
        ux(0.12),
        uy(0.62),
        ux(0.88),
        uy(0.92),
        Radius.circular(cw * 0.07),
      ),
    );
    // Casters.
    for (final f in const [0.18, 0.82]) {
      canvas.drawCircle(
        Offset(ux(f), bottom + h * 0.012),
        h * 0.018,
        Paint()..color = const Color(0xFF2A2F3A),
      );
    }
  }

  void _air(Canvas canvas, Rect outlet, double aim, double w) {
    final colors = cooling ? AirColors.mist : AirColors.breeze;
    final base = power * colors.strength * (0.72 + 0.1 * speed);
    final fan = (speed * 5 / 3).round().clamp(1, 5);
    final half = outlet.height / 2 * 0.86;
    // Out of each side and on to the edge of the room, leaning the way the
    // louvers point and sinking a little as it goes.
    for (final side in const [-1.0, 1.0]) {
      final lean = 0.55 + 0.45 * aim * side; // 0.1 .. 1
      final edge = side > 0 ? outlet.right : outlet.left;
      final reach = (side > 0 ? w - edge : edge) * (0.8 + 0.25 * lean);
      canvas.save();
      canvas.translate(edge, outlet.center.dy);
      // Turned so the stream's +y runs out to this side. Its +x is then
      // up on the right and down on the left, so a sinking bend has the
      // side's sign flipped.
      canvas.rotate(-side * math.pi / 2);
      AirFlow.paint(
        canvas,
        shader: shader,
        stream: AirStream(
          0,
          0,
          half,
          reach,
          0.35 + 0.25 * lean,
          -side * half * 0.5,
        ),
        colors: colors,
        motes: cooling ? AirMotes.mist : AirMotes.gusts,
        strength: base * lean,
        front: clock.front,
        flow: clock.flow + (side > 0 ? 0 : 17),
        fan: fan,
      );
      canvas.restore();
    }
  }

  /// The cabinet: a white shell, rounded ends lit at the rim, seams where
  /// its panels meet.
  void _cabinet(Canvas canvas, Rect r, double cw) {
    final body = RRect.fromRectAndCorners(
      r,
      topLeft: Radius.circular(cw * 0.16),
      topRight: Radius.circular(cw * 0.16),
      bottomLeft: Radius.circular(cw * 0.10),
      bottomRight: Radius.circular(cw * 0.10),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          [
            const Color(0xFFFFFFFF),
            const Color(0xFFF2F5F9),
            Color.lerp(const Color(0xFFDCE2EA), room, 0.12)!,
          ],
          const [0, 0.55, 1],
        ),
    );
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          r.centerLeft,
          r.centerRight,
          [
            _slate.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.65),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.5),
            _slate.withValues(alpha: 0.24),
          ],
          const [0, 0.05, 0.16, 0.84, 0.95, 1],
        ),
    );
    for (final f in const [0.135, 0.56]) {
      final y = r.top + r.height * f;
      canvas.drawLine(
        Offset(r.left, y),
        Offset(r.right, y),
        Paint()
          ..color = _slate.withValues(alpha: 0.22)
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        Offset(r.left, y + 1),
        Offset(r.right, y + 1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  /// The control panel on top: the speed as three bars, the mode's sign and
  /// the cooling drop, lit while it runs.
  void _panel(
    Canvas canvas,
    double Function(double) ux,
    double Function(double) uy,
    double cw,
  ) {
    final window = RRect.fromLTRBR(
      ux(0.16),
      uy(0.035),
      ux(0.84),
      uy(0.105),
      Radius.circular(cw * 0.05),
    );
    final r = window.outerRect;
    canvas.drawRRect(
      window,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
          Color(0xFF242E40),
          Color(0xFF0A0F1A),
        ]),
    );
    final lit = Color.lerp(
      const Color(0xFF2B3546),
      const Color(0xFFBFEFFF),
      power,
    )!;
    final dim = const Color(0xFF2B3546);
    // Speed: three rising bars.
    final barW = r.width * 0.055, gap = r.width * 0.035;
    for (var i = 0; i < 3; i++) {
      final bh = r.height * (0.28 + 0.16 * i);
      final x = r.left + r.width * 0.10 + i * (barW + gap);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          r.center.dy + r.height * 0.26 - bh,
          x + barW,
          r.center.dy + r.height * 0.26,
          const Radius.circular(1),
        ),
        Paint()..color = on && i < speed ? lit : dim,
      );
    }
    final modeIcon = switch (mode) {
      'natural' => Icons.eco_rounded,
      'sleep' => Icons.bedtime_rounded,
      _ => Icons.air_rounded,
    };
    _glyph(
      canvas,
      modeIcon,
      Offset(r.left + r.width * 0.62, r.center.dy),
      r.height * 0.62,
      on ? lit : dim,
    );
    _glyph(
      canvas,
      Icons.water_drop_rounded,
      Offset(r.left + r.width * 0.84, r.center.dy),
      r.height * 0.62,
      on && cooling ? Color.lerp(const Color(0xFF2B3546), _cool, power)! : dim,
    );
  }

  void _glyph(
    Canvas canvas,
    IconData icon,
    Offset c,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
          shadows: color == const Color(0xFF2B3546)
              ? null
              : [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  /// The outlet: dark inside with fixed slats across it, and the louvers in
  /// front that turn. Square on, a louver is seen edge-on, a thin line; as it
  /// turns, more of its face shows, lit on one side and shaded on the other.
  void _outletAndLouvers(Canvas canvas, RRect outlet, double aim) {
    final r = outlet.outerRect;
    canvas.drawRRect(
      outlet,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
          Color(0xFF070B12),
          Color(0xFF1C2433),
        ]),
    );
    canvas.save();
    canvas.clipRRect(outlet);
    if (power > 0.01) {
      canvas.drawRect(
        r,
        Paint()
          ..color = (cooling ? _cool : Colors.white).withValues(
            alpha: 0.18 * power,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.width * 0.15),
      );
    }
    // The fixed slats behind.
    for (var k = 1; k < 9; k++) {
      final y = r.top + r.height * k / 9;
      canvas.drawLine(
        Offset(r.left, y),
        Offset(r.right, y),
        Paint()
          ..color = const Color(0xFF3A4456)
          ..strokeWidth = 1,
      );
    }
    // The louvers in front.
    const n = 6;
    final angle = aim * 40 * math.pi / 180;
    final depth = r.width / n * 0.9;
    final face = depth * math.sin(angle).abs() + 1.6;
    for (var k = 0; k < n; k++) {
      final x = r.left + r.width * (k + 0.5) / n;
      final lean = math.sin(angle) * depth * 0.5;
      final blade = Rect.fromLTWH(
        x - face / 2 + lean * 0.5,
        r.top + 2,
        face,
        r.height - 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(blade, const Radius.circular(1.5)),
        Paint()
          ..shader = ui.Gradient.linear(blade.centerLeft, blade.centerRight, [
            angle >= 0 ? const Color(0xFFF4F6FA) : const Color(0xFFAAB4C3),
            angle >= 0 ? const Color(0xFFC3CBD7) : const Color(0xFFE9EDF3),
          ]),
      );
    }
    canvas.restore();
    canvas.drawRRect(
      outlet.inflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFCBD3DE),
    );
  }

  /// The water tank: frosted, so no water level is shown (the cooler doesn't
  /// report one). While the pump runs, bubbles rise in it.
  void _tank(Canvas canvas, RRect tank) {
    final r = tank.outerRect;
    canvas.drawRRect(
      tank,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
          const Color(0xFFE3EEF5),
          Color.lerp(
            const Color(0xFFC6D9E6),
            _cool,
            cooling ? 0.35 * power : 0,
          )!,
        ]),
    );
    canvas.save();
    canvas.clipRRect(tank);
    // Frosted ribs.
    for (var k = 1; k < 6; k++) {
      final x = r.left + r.width * k / 6;
      canvas.drawLine(
        Offset(x, r.top),
        Offset(x, r.bottom),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }
    if (cooling && power > 0.01) {
      final t = clock.seconds;
      for (var i = 0; i < 9; i++) {
        final a = (i * 0.6180339887) % 1.0;
        final v = (a + t * (0.18 + 0.1 * a)) % 1.0;
        final p = Offset(
          r.left +
              r.width * (0.12 + 0.76 * ((i * 0.7548776662) % 1.0)) +
              math.sin(t * 2 + i) * 2,
          r.bottom - r.height * v,
        );
        canvas.drawCircle(
          p,
          1.2 + 1.2 * a,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(
              alpha: power * math.sin(math.pi * v).clamp(0.0, 1.0),
            ),
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      tank,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFAEBBC9),
    );
  }

  @override
  bool shouldRepaint(_CoolerPainter old) =>
      old.shader != shader ||
      old.power != power ||
      old.on != on ||
      old.speed != speed ||
      old.cooling != cooling ||
      old.mode != mode ||
      old.room != room;
}

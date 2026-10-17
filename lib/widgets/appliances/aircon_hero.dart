import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/l10n.dart';
import 'air_flow.dart';
import 'appliance_text.dart';
import 'hero_frame.dart';

/// A wall-mounted air conditioner, drawn, that behaves like the real one: the
/// louver opens when it is switched on and the air blows out of it.
///
/// The air is a curtain of moving threads (a fragment shader) that leaves the
/// louver fast, then spreads, slows and fades; what rides in it says the mode
/// (ice sparkles and snowflakes for cool, embers for heat, droplets for dry,
/// wind streaks for fan, ice and embers for auto). Its speed follows the fan
/// speed. With swing the louver tips slowly up and down the way a real one
/// does, at an even pace with a rest at each end: tipped down the air falls
/// further down the room, tipped up it comes out at you and spreads. The air
/// already out in the room keeps the aim it left with, so each turn of the
/// louver runs out along it. Turning swing off leaves the louver where it is.
/// A change of fan speed eases in rather than jumps, and switching on sends
/// out a first gust.
/// Nothing runs while it is off, and nothing moves when the system asks for no
/// animations.
class AirconHero extends StatefulWidget {
  const AirconHero({
    super.key,
    required this.on,
    required this.mode,
    required this.temperature,
    required this.fanSpeed,
    required this.swing,
    required this.enabled,
    required this.onPower,
    this.offline = false,
  });

  final bool on;

  /// It can't be reached: the drawing is veiled and says so.
  final bool offline;

  /// 'auto', 'cool', 'dry', 'fan' or 'heat'.
  final String mode;
  final int temperature;

  /// 1 to 5.
  final int fanSpeed;
  final bool swing;

  /// Whether the power button can be pressed.
  final bool enabled;
  final ValueChanged<bool> onPower;

  @override
  State<AirconHero> createState() => _AirconHeroState();
}

class _AirconHeroState extends State<AirconHero>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = _AirClock();
  Duration _last = Duration.zero;
  bool _reduceMotion = false;
  Timer? _settle;

  /// The air's shader, once it has loaded; until then (or where there is
  /// none) the air is drawn as streaks instead.
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _clock
      ..speed = _AirClock.speedFor(widget.fanSpeed)
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
    _sync();
  }

  @override
  void didUpdateWidget(AirconHero old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) {
      // Switched on: the fan spins up and a first gust leaves the louver.
      if (widget.on && !_reduceMotion) {
        _clock
          ..speed = 0
          ..front = 0;
      }
      _sync();
    }
  }

  void _sync() {
    _settle?.cancel();
    if (_reduceMotion) _clock.front = _AirClock.fullFront;
    if (widget.on && !_reduceMotion) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      // Let the last air settle while the louver closes, then stand still:
      // a screen with nothing moving schedules no frames at all.
      _settle = Timer(const Duration(milliseconds: 750), _ticker.stop);
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _clock.advance(
      dt,
      fan: widget.fanSpeed,
      swinging: widget.swing,
      on: widget.on,
    );
  }

  @override
  void dispose() {
    _settle?.cancel();
    _ticker.dispose();
    _clock.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = _Palette.of(widget.mode, widget.on);
    final label = widget.on
        ? l10n.applAirconOn(
            optionLabel(l10n, widget.mode),
            '${widget.temperature}°C',
          )
        : l10n.applAirconOff;

    return ApplianceHeroFrame(
      label: label,
      top: palette.top,
      bottom: palette.bottom,
      buttonAccent: palette.bottom,
      on: widget.on,
      enabled: widget.enabled,
      onPower: widget.onPower,
      offline: widget.offline,
      scene: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.on ? 1.0 : 0.0),
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        builder: (context, open, _) => CustomPaint(
          painter: _AirconPainter(
            clock: _clock,
            shader: _shader,
            open: open,
            mode: widget.mode,
            fan: widget.fanSpeed.clamp(1, 5),
            temperature: widget.temperature,
            accent: palette.accent,
            room: palette.bottom,
            on: widget.on,
          ),
        ),
      ),
    );
  }
}

/// Everything that moves, moved on a little every frame. Each value carries
/// on from where it was, so a new fan speed or swing setting eases in and the
/// air never jumps.
class _AirClock extends ChangeNotifier {
  /// How far the air has travelled, in the shader's flow units.
  double flow = 0;

  /// Flow units a second; eases towards the fan speed's.
  double speed = 0;

  /// Where the louver is in its swing, 0..1 of a cycle. It only moves on
  /// while swinging, so turning swing off leaves the louver where it is.
  double phase = _middle;

  /// 0..1: how fast the swing runs. The motor starts and stops within a
  /// moment rather than at once.
  double swing = 0;

  /// The louver's aim as the air left it, by the [flow] it left at: what is
  /// still in the room, newest last.
  final _trail = <(double, double)>[];

  /// A whole swing, down and up again.
  static const swingSeconds = 10.0;

  /// The part of a cycle spent moving each way; the rest it rests at an end.
  static const _move = 0.44;
  static const _middle = _move / 2;

  /// The louver: -1 tipped up (the air comes out at you), 1 tipped down.
  double get louver {
    final c = phase % 1;
    if (c < _move) return -1 + 2 * _travel(c / _move);
    if (c < 0.5) return 1;
    if (c < 0.5 + _move) return 1 - 2 * _travel((c - 0.5) / _move);
    return -1;
  }

  /// 0..1 across one move: an even pace, with a short start and stop.
  static double _travel(double q) {
    const ramp = 0.15;
    const pace = 1 / (1 - ramp);
    if (q < ramp) return pace * q * q / (2 * ramp);
    if (q > 1 - ramp) return 1 - pace * (1 - q) * (1 - q) / (2 * ramp);
    return pace * (q - ramp / 2);
  }

  /// 0 = tipped up, 1 = tipped down.
  double get aim => 0.5 + 0.5 * louver;

  /// Where the louver aimed the air that is [trip] (0..1) of its way out:
  /// it left that many flow units ago.
  double aimAgo(double trip) {
    final at = flow - trip;
    for (var i = _trail.length - 1; i > 0; i--) {
      final (f0, a0) = _trail[i - 1];
      if (f0 <= at) {
        final (f1, a1) = _trail[i];
        final t = f1 > f0 ? ((at - f0) / (f1 - f0)).clamp(0.0, 1.0) : 1.0;
        return a0 + (a1 - a0) * t;
      }
    }
    return _trail.isEmpty ? aim : _trail.first.$2;
  }

  /// How far (0..[fullFront]) the first gust has got since switching on.
  double front = fullFront;

  /// Past the end of the air with room for the soft edge of the gust.
  static const fullFront = 1.25;

  static double speedFor(int fan) => 0.22 + 0.10 * fan.clamp(1, 5);

  void advance(
    double dt, {
    required int fan,
    required bool swinging,
    required bool on,
  }) {
    final ease = 1 - math.exp(-dt * 2.5);
    speed += (speedFor(fan) - speed) * ease;
    flow += dt * speed;
    final grip = 1 - math.exp(-dt * 8);
    swing += ((swinging ? 1.0 : 0.0) - swing) * grip;
    phase = (phase + dt * swing / swingSeconds) % 1;
    _trail.add((flow, aim));
    // Keep one whole trip out, and the sample just before it.
    var gone = 0;
    while (gone < _trail.length - 2 && _trail[gone + 1].$1 < flow - 1.05) {
      gone++;
    }
    if (gone > 0) _trail.removeRange(0, gone);
    if (on) front = math.min(front + dt / 1.1, fullFront);
    notifyListeners();
  }
}

/// The colours of the room for a mode: it is grey and quiet while off.
class _Palette {
  const _Palette(this.top, this.bottom, this.accent);
  final Color top;
  final Color bottom;
  final Color accent;

  static _Palette of(String mode, bool on) {
    if (!on) {
      return const _Palette(
        Color(0xFFF1F4FA),
        Color(0xFFDDE3EE),
        Color(0xFF94A3B8),
      );
    }
    return switch (mode) {
      'heat' => const _Palette(
        Color(0xFF8A2410),
        Color(0xFFFF8A3D),
        Color(0xFFFFC98A),
      ),
      'dry' => const _Palette(
        Color(0xFF135A56),
        Color(0xFF3CC4A8),
        Color(0xFFC4F5EA),
      ),
      'fan' => const _Palette(
        Color(0xFF334155),
        Color(0xFF8EA3C2),
        Color(0xFFFFFFFF),
      ),
      'auto' => const _Palette(
        Color(0xFF3B2A8F),
        Color(0xFF7B6CFF),
        Color(0xFFDAD4FF),
      ),
      _ => const _Palette(
        Color(0xFF0A3A8C),
        Color(0xFF2F8BFF),
        Color(0xFF8EDCFF),
      ),
    };
  }
}

class _AirconPainter extends CustomPainter {
  _AirconPainter({
    required this.clock,
    required this.shader,
    required this.open,
    required this.mode,
    required this.fan,
    required this.temperature,
    required this.accent,
    required this.room,
    required this.on,
  }) : super(repaint: clock);

  final _AirClock clock;
  final ui.FragmentShader? shader;

  /// 0 = louver shut, 1 = fully open.
  final double open;
  final String mode;
  final int fan;
  final int temperature;
  final Color accent;

  /// The room's colour, which the underside picks up.
  final Color room;
  final bool on;

  static const _slate = Color(0xFF475569);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // The unit: wide and shallow, high on the wall, seen from a little
    // below. Top to bottom: the intake grille, the glossy front panel (the
    // receiver, the lamp and the display), then the underside curving away
    // with the outlet and its flap in it.
    final bodyW = w * 0.80, bodyH = h * 0.27;
    final left = (w - bodyW) / 2, top = h * 0.09;
    final right = left + bodyW, bottom = top + bodyH;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(left, top, right, bottom),
      topLeft: Radius.circular(bodyH * 0.24),
      topRight: Radius.circular(bodyH * 0.24),
      bottomLeft: Radius.circular(bodyH * 0.40),
      bottomRight: Radius.circular(bodyH * 0.40),
    );
    // A point on the unit: across 0..1, down 0..1.
    double ux(double f) => left + bodyW * f;
    double uy(double f) => top + bodyH * f;

    // The light the air throws on the room, from the louver out (with no
    // edge of its own: it fades all the way round).
    if (open > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(w / 2, bottom + bodyH * 0.15),
            w * 0.68,
            [
              accent.withValues(alpha: 0.42 * open),
              accent.withValues(alpha: 0.12 * open),
              accent.withValues(alpha: 0),
            ],
            const [0, 0.55, 1],
          ),
      );
    }

    // Its shadow on the wall: a soft one below, a tight one all round.
    canvas.drawRRect(
      body.shift(Offset(0, bodyH * 0.16)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bodyH * 0.20),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // The shell: bright where it faces the ceiling light, a step darker where
    // the underside turns away, and that underside catches the room's colour.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            const Color(0xFFFFFFFF),
            const Color(0xFFF7F9FC),
            const Color(0xFFECF0F5),
            Color.lerp(const Color(0xFFD8DEE7), room, 0.10)!,
            Color.lerp(const Color(0xFFB9C3D1), room, 0.20)!,
          ],
          const [0, 0.30, 0.70, 0.745, 1],
        ),
    );

    canvas.save();
    canvas.clipRRect(body);
    // The rounded ends: the very edge turns away, and a rim catches the light.
    canvas.drawRect(
      body.outerRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(left, 0),
          Offset(right, 0),
          [
            _slate.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.6),
            _slate.withValues(alpha: 0.18),
          ],
          const [0, 0.022, 0.07, 0.93, 0.978, 1],
        ),
    );
    // A soft reflection across the glossy panel.
    final sheen = Rect.fromLTRB(left, uy(0.28), right, uy(0.56));
    canvas.drawRect(
      sheen,
      Paint()
        ..shader = ui.Gradient.linear(
          sheen.topCenter,
          sheen.bottomCenter,
          [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0),
          ],
          const [0, 0.45, 1],
        ),
    );
    // The intake grille along the top, and the joint under it.
    for (var k = 0; k < 5; k++) {
      _groove(canvas, ux(0.05), ux(0.95), uy(0.07 + k * 0.03), 0.12);
    }
    _groove(canvas, ux(0.03), ux(0.97), uy(0.235), 0.22);
    // Where the front panel ends and the underside begins: the panel's lit
    // edge, then the gap.
    canvas.drawLine(
      Offset(ux(0.03), uy(0.712)),
      Offset(ux(0.97), uy(0.712)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(ux(0.03), uy(0.728)),
      Offset(ux(0.97), uy(0.728)),
      Paint()
        ..color = _slate.withValues(alpha: 0.30)
        ..strokeWidth = 1,
    );
    // The end caps' joints.
    for (final f in const [0.035, 0.965]) {
      canvas.drawLine(
        Offset(ux(f), uy(0.24)),
        Offset(ux(f), uy(0.71)),
        Paint()
          ..color = _slate.withValues(alpha: 0.10)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();

    // The remote's receiver window and the lamp beside it.
    final receiver = RRect.fromLTRBR(
      ux(0.055),
      uy(0.40),
      ux(0.092),
      uy(0.53),
      Radius.circular(bodyH * 0.035),
    );
    canvas.drawRRect(
      receiver,
      Paint()
        ..shader = ui.Gradient.linear(
          receiver.outerRect.topCenter,
          receiver.outerRect.bottomCenter,
          const [Color(0xFF2A3446), Color(0xFF0D131F)],
        ),
    );
    canvas.drawCircle(
      Offset(receiver.left + receiver.width * 0.3, receiver.top + 2.2),
      0.9,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    final lamp = Offset(ux(0.118), uy(0.465));
    final lampR = bodyH * 0.03;
    if (on) {
      canvas.drawCircle(
        lamp,
        lampR * 2.6,
        Paint()
          ..color = const Color(0xFF4ADE80).withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, lampR * 1.4),
      );
    }
    canvas.drawCircle(
      lamp,
      lampR,
      Paint()..color = on ? const Color(0xFF86EFAC) : const Color(0xFFC3CBD6),
    );

    _display(
      canvas,
      RRect.fromLTRBR(
        ux(0.69),
        uy(0.32),
        ux(0.925),
        uy(0.635),
        Radius.circular(bodyH * 0.07),
      ),
    );

    // The outlet in the underside, and the flap that closes it. Open, the
    // flap is a slim blade hanging from the outlet's front lip, which shows
    // the dark inside, its vanes, and the air's colour glowing in it.
    final louver = clock.louver;
    final louverL = ux(0.07), louverR = ux(0.93);
    final opening = RRect.fromLTRBR(
      louverL,
      uy(0.80),
      louverR,
      uy(0.95),
      Radius.circular(bodyH * 0.05),
    );
    if (open > 0.01) _outlet(canvas, opening, bodyH);
    // The blade turns about the lip: 40° below level, and with swing it folds
    // up to point almost at you (nearly edge-on, a thin dark line) and down
    // again to show its whole lit face. We look up at it a little, so what
    // shows of it is its depth times sin(angle + look).
    final angle = (40 + 32 * louver) * math.pi / 180;
    const look = 15 * math.pi / 180;
    final hinge = opening.bottom - opening.height * 0.10;
    final shown = math.max(bodyH * 0.18 * math.sin(angle + look), 1.5);
    final flapTop = ui.lerpDouble(opening.top, hinge, open)!;
    final flapBottom = ui.lerpDouble(opening.bottom, hinge + shown, open)!;
    final flap = RRect.fromLTRBR(
      louverL,
      flapTop,
      louverR,
      flapBottom,
      Radius.circular(math.min(bodyH * 0.04, (flapBottom - flapTop) / 2)),
    );
    _flap(canvas, flap, math.sin(angle).clamp(0.0, 1.0));

    if (open <= 0.02) return;

    // The air. Where the louver points it: tipped further down, it reaches
    // further down the room; tipped up, it comes out at you and spreads. The
    // air out in the room left a moment ago, with the aim it had then.
    double spread(double aim) => 0.25 + 0.45 * (1 - aim);
    double length(double aim) => 0.82 + 0.18 * aim;
    AirKnots carried(double Function(double aim) f) => AirKnots(
      f(clock.aimAgo(0)),
      f(clock.aimAgo(1 / 3)),
      f(clock.aimAgo(2 / 3)),
      f(clock.aimAgo(1)),
    );
    final stream = AirStream(
      (louverL + louverR) / 2,
      flap.bottom,
      (louverR - louverL) / 2 * 0.92,
      h - flap.bottom,
      spread(clock.aim),
      0,
      spreads: carried(spread),
      lengths: carried(length),
    );
    final colors = AirColors.forMode(mode);
    AirFlow.paint(
      canvas,
      shader: shader,
      stream: stream,
      colors: colors,
      motes: AirMotes.forMode(mode),
      strength: open * colors.strength * (0.78 + 0.06 * fan),
      front: clock.front,
      flow: clock.flow,
      fan: fan,
    );
  }

  /// A groove across the shell: a shadowed line with a lit one under it.
  void _groove(Canvas canvas, double x0, double x1, double y, double depth) {
    canvas.drawLine(
      Offset(x0, y),
      Offset(x1, y),
      Paint()
        ..color = _slate.withValues(alpha: depth)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(x0, y + 1),
      Offset(x1, y + 1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 1,
    );
  }

  static IconData _modeIcon(String mode) =>
      modeIcon(mode) ?? Icons.ac_unit_rounded;

  /// The display behind its smoked window: the mode's sign and the set
  /// temperature in glowing figures while it runs, dark while it is off.
  void _display(Canvas canvas, RRect window) {
    final r = window.outerRect;
    canvas.drawRRect(
      window.inflate(1),
      Paint()..color = const Color(0xFFCBD3DE),
    );
    canvas.drawRRect(
      window,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
          Color(0xFF242E40),
          Color(0xFF0A0F1A),
        ]),
    );

    final led = on ? accent : const Color(0xFF2B3546);
    final glow = on
        ? [
            Shadow(color: accent.withValues(alpha: 0.9), blurRadius: 5),
            Shadow(color: accent.withValues(alpha: 0.45), blurRadius: 12),
          ]
        : const <Shadow>[];
    if (on) {
      final icon = _modeIcon(mode);
      _label(
        canvas,
        String.fromCharCode(icon.codePoint),
        TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: r.height * 0.46,
          color: led,
          shadows: glow,
        ),
        Offset(r.left + r.width * 0.07, r.center.dy),
        fromLeft: true,
      );
    }
    _label(
      canvas,
      on ? '$temperature°' : '--',
      TextStyle(
        color: led,
        fontSize: r.height * 0.60,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: glow,
      ),
      Offset(r.right - r.width * 0.07, r.center.dy),
      fromLeft: false,
    );

    // The glass: a lit top edge and a faint reflection across it.
    canvas.save();
    canvas.clipRRect(window);
    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.top)
        ..lineTo(r.left + r.width * 0.55, r.top)
        ..lineTo(r.left + r.width * 0.30, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    canvas.drawLine(
      Offset(r.left + 3, r.top + 0.75),
      Offset(r.right - 3, r.top + 0.75),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  /// Inside the outlet: dark, with the vanes that aim the air left and
  /// right, and the air's colour glowing through.
  void _outlet(Canvas canvas, RRect opening, double bodyH) {
    final r = opening.outerRect;
    canvas.save();
    canvas.clipRRect(opening);
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
          const Color(0xFF04070D).withValues(alpha: open),
          const Color(0xFF1B2332).withValues(alpha: open),
        ]),
    );
    canvas.drawRect(
      Rect.fromLTRB(r.left, r.center.dy, r.right, r.bottom + r.height * 0.3),
      Paint()
        ..color = accent.withValues(alpha: 0.45 * open)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.height * 0.3),
    );
    const vanes = 13;
    for (var k = 0; k < vanes; k++) {
      final x = r.left + r.width * (k + 0.5) / vanes;
      // The vanes fan out a little from the middle.
      final lean = (x - r.center.dx) / r.width;
      final a = Offset(x + lean * 4, r.top);
      final b = Offset(x + lean * 14, r.bottom);
      canvas.drawLine(
        a.translate(1.3, 0),
        b.translate(1.3, 0),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45 * open)
          ..strokeWidth = 1.4,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFF8C9AB0).withValues(alpha: 0.75 * open)
          ..strokeWidth = 1.4,
      );
    }
    canvas.restore();
  }

  /// The flap. Shut, it is part of the underside; open, it is a thin curved
  /// blade: in the body's shadow at the top, brightest where its curve meets
  /// the light, darker again at its leading edge, with the air's colour on it
  /// where the air leaves. [facing] (0..1) is how far its outer face has
  /// turned to you: folded up you see its shaded underside, turned down its
  /// lit face.
  void _flap(Canvas canvas, RRect flap, double facing) {
    final r = flap.outerRect;
    Color shut(Color c) => Color.lerp(c, room, 0.18)!;
    const shutShades = [
      Color(0xFFD0D7E1),
      Color(0xFFC9D1DC),
      Color(0xFFC4CCD8),
      Color(0xFFC0C9D5),
      Color(0xFFBEC7D4),
    ];
    const litShades = [
      Color(0xFF8D98AA),
      Color(0xFFDDE3EB),
      Color(0xFFFFFFFF),
      Color(0xFFE6EBF1),
      Color(0xFFAEB8C7),
    ];
    const shadedShades = [
      Color(0xFF6F7B8F),
      Color(0xFF9AA5B6),
      Color(0xFFB4BDCA),
      Color(0xFFA7B1C0),
      Color(0xFF7F8A9D),
    ];
    canvas.drawRRect(
      flap,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          [
            for (var i = 0; i < shutShades.length; i++)
              Color.lerp(
                shut(shutShades[i]),
                Color.lerp(shadedShades[i], litShades[i], facing)!,
                open,
              )!,
          ],
          const [0, 0.35, 0.70, 0.90, 1],
        ),
    );
    if (open > 0.01) {
      canvas.save();
      canvas.clipRRect(flap);
      canvas.drawRect(
        Rect.fromLTRB(r.left, r.top - 4, r.right, r.top + r.height * 0.35),
        Paint()
          ..color = accent.withValues(alpha: 0.30 * open)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.height * 0.15),
      );
      canvas.restore();
    }
    canvas.drawRRect(
      flap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF8F9BAE).withValues(alpha: 0.7),
    );
  }

  void _label(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor, {
    required bool fromLeft,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        fromLeft ? anchor.dx : anchor.dx - tp.width,
        anchor.dy - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_AirconPainter old) =>
      old.shader != shader ||
      old.open != open ||
      old.mode != mode ||
      old.fan != fan ||
      old.temperature != temperature ||
      old.accent != accent ||
      old.room != room ||
      old.on != on;
}

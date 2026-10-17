import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'air_flow.dart';
import 'appliance_status.dart';
import 'hero_frame.dart';

/// A quartz tower heater, drawn: an ivory cabinet with a dial on top and a
/// grille over three heating tubes.
///
/// Switched on, the tubes warm up the way real ones do, over a few seconds,
/// to an orange glow; hot air shimmers up in front of them and the room
/// warms. Switched off, they cool down again. The dial turns by hand-speed
/// rather than jumping, and the lamp lights as it passes halfway. While it is on and the server
/// will switch it off by itself ([autoOffAt]), a ring round the power button
/// counts the time down, with the time left beside it. Nothing moves when the
/// system asks for no animations.
class HeaterHero extends StatefulWidget {
  const HeaterHero({
    super.key,
    required this.on,
    required this.enabled,
    required this.onPower,
    this.since,
    this.autoOffAt,
    this.offline = false,
    this.clock = DateTime.now,
  });

  final bool on;

  /// Since when it has been on, when known: the countdown's full length.
  final DateTime? since;

  /// When the server will switch it off by itself.
  final DateTime? autoOffAt;

  /// Whether the power button can be pressed.
  final bool enabled;
  final ValueChanged<bool> onPower;
  final bool offline;
  final DateTime Function() clock;

  @override
  State<HeaterHero> createState() => _HeaterHeroState();
}

class _HeaterHeroState extends State<HeaterHero>
    with SingleTickerProviderStateMixin {
  late final _HeaterClock _clock = _HeaterClock(this, () => widget.on);
  bool _reduceMotion = false;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _clock.glow = _clock.dial = widget.on ? 1 : 0;
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
  void didUpdateWidget(HeaterHero old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) _sync();
  }

  void _sync() {
    if (_reduceMotion) {
      _clock.glow = _clock.dial = widget.on ? 1 : 0;
      _clock.run(false);
      return;
    }
    // Warming up, running, or cooling down: the clock stops itself once the
    // tubes are cold and the dial is back.
    _clock.run(widget.on || _clock.glow > 0.005 || _clock.dial > 0.005);
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
    final off = widget.autoOffAt;
    final now = widget.clock();
    final label = !widget.on
        ? l10n.applHeaterOff
        : off != null
        ? l10n.applHeaterOnAutoOff(applianceDuration(l10n, off.difference(now)))
        : l10n.applHeaterOn;

    return ApplianceHeroFrame(
      label: label,
      top: widget.on ? const Color(0xFF2E1A14) : const Color(0xFFF1F4FA),
      bottom: widget.on ? const Color(0xFF8E4424) : const Color(0xFFDDE3EE),
      buttonAccent: const Color(0xFFE0661F),
      on: widget.on,
      enabled: widget.enabled,
      onPower: widget.onPower,
      offline: widget.offline,
      scene: CustomPaint(
        painter: _HeaterPainter(
          clock: _clock,
          shader: _shader,
          on: widget.on,
          since: widget.since,
          autoOffAt: off,
          now: widget.clock,
          offInLabel: l10n.applHeaterOffIn,
        ),
      ),
    );
  }
}

/// How hot the tubes are and how far the dial is turned, moved on each frame:
/// the tubes take a few seconds to glow and a little less to go dark; a hand
/// turns the dial in well under a second.
class _HeaterClock extends HeroClock {
  _HeaterClock(super.vsync, this._on);

  final bool Function() _on;

  /// 0 = cold, 1 = glowing.
  double glow = 0;

  /// 0 = turned off, 1 = turned to "on".
  double dial = 0;

  static const _dialSeconds = 0.7;

  @override
  void advance(double dt) {
    final on = _on();
    final rate = on ? 1 / 2.6 : 1 / 1.6;
    glow = on ? math.min(1, glow + dt * rate) : math.max(0, glow - dt * rate);
    final turn = dt / _dialSeconds;
    dial = on ? math.min(1, dial + turn) : math.max(0, dial - turn);
    // Cold again and the dial back: nothing left to move.
    if (!on && glow <= 0 && dial <= 0) stop();
  }
}

class _HeaterPainter extends CustomPainter {
  _HeaterPainter({
    required this.clock,
    required this.shader,
    required this.on,
    required this.since,
    required this.autoOffAt,
    required this.now,
    required this.offInLabel,
  }) : super(repaint: clock);

  final _HeaterClock clock;
  final ui.FragmentShader? shader;
  final bool on;
  final DateTime? since;
  final DateTime? autoOffAt;
  final DateTime Function() now;
  final String offInLabel;

  static const _ember = Color(0xFFFF7A1A);
  static const _hot = Color(0xFFFFB25A);
  static const _white = Color(0xFFFFE9C2);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Eased, so it creeps in and settles like a real element.
    final g = Curves.easeInOut.transform(clock.glow.clamp(0.0, 1.0));
    final bw = w * 0.30, bh = h * 0.60;
    final left = (w - bw) / 2, top = h * 0.06;
    final body = Rect.fromLTWH(left, top, bw, bh);
    final cx = w / 2;

    // The warmth it throws on the room.
    if (g > 0.01) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, top + bh * 0.5),
            w * 0.7,
            [
              _ember.withValues(alpha: 0.45 * g),
              _ember.withValues(alpha: 0.12 * g),
              _ember.withValues(alpha: 0),
            ],
            const [0, 0.5, 1],
          ),
      );
    }

    // The stand and its shadow.
    final base = Rect.fromCenter(
      center: Offset(cx, body.bottom + h * 0.035),
      width: bw * 1.25,
      height: h * 0.045,
    );
    canvas.drawOval(
      base.shift(Offset(0, h * 0.012)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.012),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, body.bottom + h * 0.015),
        width: bw * 0.18,
        height: h * 0.04,
      ),
      Paint()..color = const Color(0xFFB9B3A8),
    );
    canvas.drawOval(
      base,
      Paint()
        ..shader = ui.Gradient.linear(base.topCenter, base.bottomCenter, const [
          Color(0xFFE9E5DD),
          Color(0xFFB9B3A8),
        ]),
    );

    // The cabinet: ivory, rounded, lit from above and rounded at the sides.
    final shell = RRect.fromRectAndRadius(body, Radius.circular(bw * 0.16));
    canvas.drawRRect(
      shell.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = ui.Gradient.linear(body.topCenter, body.bottomCenter, const [
          Color(0xFFFBF9F5),
          Color(0xFFE4DFD6),
        ]),
    );
    canvas.save();
    canvas.clipRRect(shell);
    canvas.drawRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          body.centerLeft,
          body.centerRight,
          [
            const Color(0xFF6B6255).withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.45),
            const Color(0xFF6B6255).withValues(alpha: 0.26),
          ],
          const [0, 0.05, 0.16, 0.84, 0.95, 1],
        ),
    );
    canvas.restore();

    // On top: the dial, turned to "on", and the lamp beside it.
    final dial = Offset(left + bw * 0.38, top + bh * 0.085);
    final dialR = bw * 0.085;
    canvas.drawCircle(
      dial.translate(0, 1.2),
      dialR,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      dial,
      dialR,
      Paint()
        ..shader = ui.Gradient.radial(
          dial.translate(-dialR * 0.3, -dialR * 0.3),
          dialR * 1.3,
          const [Color(0xFFFFFFFF), Color(0xFFCFC9BE)],
        ),
    );
    // Eased like a hand turning it: it leaves slowly, hurries, and settles.
    final d = Curves.easeInOut.transform(clock.dial.clamp(0.0, 1.0));
    final turn = -math.pi / 2 + math.pi * 0.6 * d;
    canvas.drawLine(
      dial,
      dial + Offset(math.cos(turn), math.sin(turn)) * dialR * 0.75,
      Paint()
        ..color = const Color(0xFF5A5247)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // The lamp lights as the dial passes halfway, and goes out as it does.
    final lit = ((d - 0.5) * 2).clamp(0.0, 1.0);
    final lamp = Offset(left + bw * 0.66, dial.dy);
    if (lit > 0) {
      canvas.drawCircle(
        lamp,
        dialR * 0.9,
        Paint()
          ..color = const Color(0xFFFF4A2A).withValues(alpha: 0.55 * lit)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, dialR * 0.5),
      );
    }
    canvas.drawCircle(
      lamp,
      dialR * 0.32,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFC9C3B8),
          const Color(0xFFFF6A4A),
          lit,
        )!,
    );

    // The window: a reflector behind three tubes, and a guard over them.
    final win = RRect.fromLTRBR(
      left + bw * 0.13,
      top + bh * 0.18,
      left + bw * 0.87,
      top + bh * 0.88,
      Radius.circular(bw * 0.07),
    );
    final wr = win.outerRect;
    canvas.drawRRect(
      win,
      Paint()
        ..shader = ui.Gradient.linear(
          wr.centerLeft,
          wr.centerRight,
          [
            Color.lerp(const Color(0xFF2B3039), const Color(0xFF5A2410), g)!,
            Color.lerp(const Color(0xFF6A717C), const Color(0xFFC0602A), g)!,
            Color.lerp(const Color(0xFF2B3039), const Color(0xFF5A2410), g)!,
          ],
          const [0, 0.5, 1],
        ),
    );
    canvas.save();
    canvas.clipRRect(win);
    // A flicker so slight it reads as heat, not as a fault.
    final t = clock.seconds;
    for (var k = 0; k < 3; k++) {
      final y = wr.top + wr.height * (0.22 + 0.28 * k);
      final flicker = 1 - 0.06 * g * (0.5 + 0.5 * math.sin(t * 7.3 + k * 2.1));
      final heat = g * flicker;
      final tube = RRect.fromLTRBR(
        wr.left + wr.width * 0.08,
        y - 4,
        wr.right - wr.width * 0.08,
        y + 4,
        const Radius.circular(4),
      );
      if (heat > 0.01) {
        canvas.drawRRect(
          tube.inflate(5),
          Paint()
            ..color = _ember.withValues(alpha: 0.55 * heat)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      final r = tube.outerRect;
      canvas.drawRRect(
        tube,
        Paint()
          ..shader = ui.Gradient.linear(
            r.topCenter,
            r.bottomCenter,
            [
              Color.lerp(const Color(0xFFDDE1E6), _white, heat)!,
              Color.lerp(const Color(0xFF8E959F), _hot, heat)!,
              Color.lerp(const Color(0xFF5C636D), _ember, heat)!,
            ],
            const [0, 0.45, 1],
          ),
      );
    }
    canvas.restore();
    // The guard: thin bars across the window, and its frame.
    for (var k = 1; k < 9; k++) {
      final x = wr.left + wr.width * k / 9;
      canvas.drawLine(
        Offset(x, wr.top),
        Offset(x, wr.bottom),
        Paint()
          ..color = const Color(0xFFD9D4CA).withValues(alpha: 0.75)
          ..strokeWidth = 1.2,
      );
    }
    canvas.drawRRect(
      win,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFCFC9BE),
    );

    // Hot air shimmering up in front of the tubes.
    if (g > 0.02) {
      canvas.save();
      canvas.translate(cx, wr.bottom);
      canvas.rotate(math.pi); // the stream's +y now runs up
      AirFlow.paint(
        canvas,
        shader: shader,
        stream: AirStream(0, 0, wr.width * 0.42, wr.bottom * 0.98, 0.5, 0),
        colors: AirColors.forMode('heat'),
        motes: AirMotes.embers,
        strength: 0.42 * g,
        front: 1.25,
        flow: t * 0.35,
        fan: 2,
      );
      canvas.restore();
    }

    _countdown(canvas, size);
  }

  /// Round the power button: how much of the run is left before the server
  /// switches it off, and the time left beside it.
  void _countdown(Canvas canvas, Size size) {
    final off = autoOffAt;
    if (!on || off == null) return;
    final n = now();
    final left = off.difference(n);
    final start = since;
    final total = start != null && off.isAfter(start)
        ? off.difference(start)
        : const Duration(hours: 2);
    final frac = (left.inSeconds / math.max(total.inSeconds, 1)).clamp(
      0.0,
      1.0,
    );

    // The power button: 60 across, 14 up from the bottom (see the frame).
    final c = Offset(size.width / 2, size.height - 14 - 30);
    const r = 37.0;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * frac,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = _hot,
    );

    final secs = math.max(left.inSeconds, 0);
    final hh = secs ~/ 3600, mm = (secs % 3600) ~/ 60;
    final time = '$hh:${mm.toString().padLeft(2, '0')}';
    final small = TextPainter(
      text: TextSpan(
        text: offInLabel,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final big = TextPainter(
      text: TextSpan(
        text: time,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = c.dx + r + 12;
    final y = c.dy - (small.height + big.height) / 2;
    small.paint(canvas, Offset(x, y));
    big.paint(canvas, Offset(x, y + small.height));
  }

  @override
  bool shouldRepaint(_HeaterPainter old) =>
      old.shader != shader ||
      old.on != on ||
      old.since != since ||
      old.autoOffAt != autoOffAt ||
      old.offInLabel != offInLabel;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The air's shader program, or null where it cannot be had (the air is then
/// drawn as streaks). dart:ui keeps a program once loaded, so every drawing
/// after the first gets it at once.
Future<ui.FragmentProgram?> loadAirShader() => ui.FragmentProgram.fromAsset(
  'shaders/aircon_air.frag',
).then<ui.FragmentProgram?>((p) => p, onError: (Object _) => null);

/// How many floats the air's shader takes, in the order [AirFlow] sets them
/// (see `shaders/aircon_air.frag`).
@visibleForTesting
const airShaderUniformCount = 26;

/// The colours of the air, and how thick it is.
class AirColors {
  const AirColors(this.index, this.near, this.far, this.warm, this.strength);

  /// The style as the shader numbers it: 0 cool, 1 heat (it wavers), 2 dry,
  /// 3 fan, 4 auto (warm turning over cool).
  final double index;
  final Color near;
  final Color far;
  final Color warm;
  final double strength;

  static const _warm = Color(0xFFFFC48A);

  /// An air conditioner's, by its mode.
  static AirColors forMode(String mode) => switch (mode) {
    'heat' => const AirColors(
      1,
      Color(0xFFFFF4D6),
      Color(0xFFFFB067),
      _warm,
      0.95,
    ),
    'dry' => const AirColors(
      2,
      Color(0xFFF0FFFB),
      Color(0xFF9FF0DC),
      _warm,
      0.80,
    ),
    'fan' => const AirColors(
      3,
      Color(0xFFFFFFFF),
      Color(0xFFDCE6F5),
      _warm,
      0.85,
    ),
    'auto' => const AirColors(
      4,
      Color(0xFFF4F2FF),
      Color(0xFFA8E6FF),
      _warm,
      1.0,
    ),
    _ => const AirColors(0, Color(0xFFF2FDFF), Color(0xFF8FE3FF), _warm, 1.0),
  };

  /// Air that has passed over wet pads: cool, and carrying fine mist.
  static const mist = AirColors(
    2,
    Color(0xFFF2FDFF),
    Color(0xFFA5E8F7),
    _warm,
    0.9,
  );

  /// Plain moving air.
  static const breeze = AirColors(
    3,
    Color(0xFFFFFFFF),
    Color(0xFFDCE6F5),
    _warm,
    0.8,
  );
}

/// What rides in the air.
enum AirMotes {
  /// Ice glints and the odd snowflake.
  ice,

  /// Glowing embers.
  embers,

  /// Drops of water.
  droplets,

  /// Streaks of wind.
  gusts,

  /// Ice and embers, turn about.
  iceAndEmbers,

  /// Fine mist: small soft beads.
  mist;

  /// An air conditioner's, by its mode.
  static AirMotes forMode(String mode) => switch (mode) {
    'heat' => embers,
    'dry' => droplets,
    'fan' => gusts,
    'auto' => iceAndEmbers,
    _ => ice,
  };
}

/// Four values the air carries, at 0, 1/3, 2/3 and all of its trip out, and
/// the smooth curve through them. What air out in the room carries is what it
/// left the outlet with, a moment ago, so a change runs out along the air.
/// The shader's `knots` is the same curve.
class AirKnots {
  const AirKnots(this.a, this.b, this.c, this.d);
  const AirKnots.all(double v) : a = v, b = v, c = v, d = v;

  final double a, b, c, d;

  /// At [trip] (0..1) of the way out.
  double at(double trip) {
    final u = trip.clamp(0.0, 1.0) * 3;
    return -a * (u - 1) * (u - 2) * (u - 3) / 6 +
        b * u * (u - 2) * (u - 3) / 2 -
        c * u * (u - 1) * (u - 3) / 2 +
        d * u * (u - 1) * (u - 2) / 6;
  }

  double get max => math.max(math.max(a, b), math.max(c, d));
}

/// The shape of the moving air: it leaves the outlet [half] either side of
/// [cx] at [top], fans out by [spread] and bends sideways by [bend] as it goes
/// [reach] along +y. The shader draws the same shape. Turn the canvas to send
/// it another way.
///
/// Air whose aim changes as it goes says so with [spreads] (in place of
/// [spread]) and [lengths]: how much of [reach] it gets before it has faded.
class AirStream {
  const AirStream(
    this.cx,
    this.top,
    this.half,
    this.reach,
    this.spread,
    this.bend, {
    this.spreads,
    this.lengths,
  });

  final double cx, top, half, reach, spread, bend;
  final AirKnots? spreads;
  final AirKnots? lengths;

  /// How far along its trip air [v] (0..1) of the way along is: it leaves
  /// fast and slows (the shader's s).
  static double trip(double v) {
    final c = v.clamp(0.0, 1.0);
    return c * (0.6 + 0.4 * c);
  }

  /// How far along air is that set off [phase] (0..1) of its trip ago: the
  /// inverse of [trip].
  static double along(double phase) =>
      (-0.6 + math.sqrt(0.36 + 1.6 * phase)) / 0.8;

  /// How far it fans out, [v] of the way along.
  double spreadAt(double v) => math.max(spreads?.at(trip(v)) ?? spread, 0);

  /// How much of [reach] the air at [v] gets before it has faded.
  double lengthAt(double v) =>
      (lengths?.at(trip(v)) ?? 1.0).clamp(0.3, 1.0).toDouble();

  /// Where air [x] across the stream (-1..1) is, [v] (0..1) of the way along.
  /// It goes straight out of the outlet, then flares out.
  Offset at(double x, double v) => Offset(
    cx +
        bend * v * v +
        x * half * (1 + spreadAt(v) * 1.5 * v * (0.4 + 0.6 * v)),
    top + reach * v,
  );

  /// Everything the air can reach, for the shader to fill.
  Rect get bounds {
    final most = spreads?.max ?? spread;
    final widest = half * (1 + most * 1.5) * 1.1 + bend.abs();
    return Rect.fromLTRB(cx - widest, top, cx + widest, top + reach);
  }
}

/// Draws moving air: its body (by the shader, or as streaks without it) and
/// what rides in it.
class AirFlow {
  const AirFlow._();

  static const _goldenRatio = 0.6180339887;
  static const _plastic = 0.7548776662;

  /// [flow] is how far the air has travelled, in the shader's flow units;
  /// [front] how far (0..1.25) the first gust has got; [fan] 1..5 sets how
  /// much rides in it.
  static void paint(
    Canvas canvas, {
    required ui.FragmentShader? shader,
    required AirStream stream,
    required AirColors colors,
    required AirMotes motes,
    required double strength,
    required double front,
    required double flow,
    required int fan,
  }) {
    final s = shader;
    if (s != null) {
      _curtain(canvas, s, stream, colors, strength, front, flow);
    } else {
      _streaks(canvas, stream, colors, strength, front, flow, fan);
    }
    _motes(canvas, stream, motes, strength, front, flow, fan);
  }

  /// The body of the air, by the shader.
  static void _curtain(
    Canvas canvas,
    ui.FragmentShader shader,
    AirStream s,
    AirColors colors,
    double strength,
    double front,
    double flow,
  ) {
    var i = 0;
    void put(double value) => shader.setFloat(i++, value);
    void colour(Color c) {
      put(c.r);
      put(c.g);
      put(c.b);
    }

    void knots(AirKnots k) {
      put(k.a);
      put(k.b);
      put(k.c);
      put(k.d);
    }

    put(s.cx);
    put(s.top);
    put(s.half);
    put(s.reach);
    knots(s.spreads ?? AirKnots.all(s.spread));
    knots(s.lengths ?? const AirKnots.all(1));
    put(s.bend);
    put(strength);
    put(front);
    colour(colors.near);
    colour(colors.far);
    colour(colors.warm);
    // The shader's noise repeats every 64 flow units.
    put(flow % 64);
    put(colors.index);

    canvas.drawRect(s.bounds, Paint()..shader = shader);
  }

  /// The body of the air without the shader: soft streaks that run along the
  /// stream and taper to their tails.
  static void _streaks(
    Canvas canvas,
    AirStream s,
    AirColors colors,
    double strength,
    double front,
    double flow,
    int fan,
  ) {
    final n = 6 + fan * 2;
    const steps = 8;
    const tail = 0.30;
    for (var j = 0; j < n; j++) {
      final seed = (j * _goldenRatio + 0.13) % 1.0;
      final x0 = -0.85 + 1.7 * (j + 0.5) / n + (seed - 0.5) * 0.12;
      final head =
          AirStream.along((flow * (1.6 + 0.5 * seed) + seed) % 1.0) * 1.3;
      Offset? prev;
      for (var k = 0; k <= steps; k++) {
        final f = k / steps; // 0 at the tail, 1 at the head
        final v = head - tail * (1 - f);
        if (v < 0 || v > math.min(front, 1)) {
          prev = null;
          continue;
        }
        final p = s.at(x0 + 0.05 * math.sin(v * 7 + j * 1.9), v);
        if (prev != null) {
          final len = s.lengthAt(v);
          final fade = 1 - _smooth(0.45 * len, len, v);
          canvas.drawLine(
            prev,
            p,
            Paint()
              ..strokeCap = StrokeCap.round
              ..strokeWidth = (0.8 + 2.0 * f) * (1 + 0.5 * v)
              ..color = Color.lerp(
                colors.near,
                colors.far,
                v,
              )!.withValues(alpha: (strength * f * f * fade).clamp(0.0, 1.0)),
          );
        }
        prev = p;
      }
    }
  }

  /// What rides in the air: it comes nearer (and bigger) as it goes.
  static void _motes(
    Canvas canvas,
    AirStream s,
    AirMotes motes,
    double strength,
    double front,
    double flow,
    int fan,
  ) {
    final n = switch (motes) {
      AirMotes.embers => 10 + fan * 2,
      AirMotes.droplets => 7 + fan,
      AirMotes.gusts => 8 + fan * 3,
      AirMotes.mist => 14 + fan * 3,
      _ => 12 + fan * 2,
    };
    for (var i = 0; i < n; i++) {
      final seed = (i * _goldenRatio) % 1.0;
      final seed2 = (i * _plastic + 0.31) % 1.0;
      final rate = 0.8 + 0.5 * seed2;
      final phase = (flow * rate + seed) % 1.0;
      final v = AirStream.along(phase);
      if (v > front) continue;
      final x = (seed2 * 2 - 1) * 0.85 + 0.07 * math.sin(flow * 3 + i * 1.3);
      final len = s.lengthAt(v);
      final fade =
          math.pow(math.sin(math.pi * phase), 0.6).toDouble() *
          (1 - _smooth(0.55 * len, len, v));
      final alpha = (strength * fade).clamp(0.0, 1.0);
      if (alpha < 0.02) continue;
      final p = s.at(x, v);
      final near = 1 + 0.9 * v;

      final style = motes == AirMotes.iceAndEmbers
          ? (i.isEven ? AirMotes.ice : AirMotes.embers)
          : motes;
      switch (style) {
        case AirMotes.embers:
          final flicker = 0.6 + 0.4 * math.sin(flow * 11 + i * 2.1);
          _ember(canvas, p, 1.7 * near, alpha * flicker, i);
        case AirMotes.droplets:
          _droplet(canvas, p, 2.8 * near, alpha);
        case AirMotes.gusts:
          final ahead = s.at(x, math.min(v + 0.08, 1));
          _gust(canvas, p, ahead, alpha);
        case AirMotes.mist:
          _bead(canvas, p, (0.9 + 0.6 * seed) * near, alpha);
        case AirMotes.ice:
        case AirMotes.iceAndEmbers:
          if (i % 7 == 0) {
            _snowflake(canvas, p, 3.2 * near, alpha, flow * 2 + i);
          } else {
            final twinkle = 0.55 + 0.45 * math.sin(flow * 9 + i * 2.3);
            _sparkle(canvas, p, 1.5 * near, alpha * twinkle);
          }
      }
    }
  }

  /// A glint of ice: a four-pointed star with a little glow.
  static void _sparkle(Canvas canvas, Offset p, double r, double alpha) {
    canvas.drawCircle(
      p,
      r * 1.6,
      Paint()
        ..color = const Color(0xFFCFF6FF).withValues(alpha: alpha * 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
    );
    final arm = r * 2.2;
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - arm)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + arm, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + arm)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - arm, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - arm)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
  }

  /// A snowflake: six arms, each with a pair of little branches, turning.
  static void _snowflake(
    Canvas c,
    Offset p,
    double r,
    double alpha,
    double spin,
  ) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: alpha);
    c.drawCircle(
      p,
      r * 0.9,
      Paint()
        ..color = const Color(0xFFCFF6FF).withValues(alpha: alpha * 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
    );
    for (var k = 0; k < 6; k++) {
      final a = spin + k * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a));
      final tip = p + d * r;
      c.drawLine(p, tip, paint);
      final mid = p + d * r * 0.55;
      for (final side in const [-1.0, 1.0]) {
        final b = a + side * math.pi / 4;
        c.drawLine(
          mid,
          mid + Offset(math.cos(b), math.sin(b)) * r * 0.35,
          paint,
        );
      }
    }
  }

  /// A glowing ember.
  static void _ember(Canvas canvas, Offset p, double r, double alpha, int i) {
    final hot = Color.lerp(
      const Color(0xFFFFE6A8),
      const Color(0xFFFF7A2E),
      (i % 3) / 2,
    )!;
    canvas.drawCircle(
      p,
      r * 2.4,
      Paint()
        ..color = hot.withValues(alpha: alpha * 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.6),
    );
    canvas.drawCircle(
      p,
      r * 0.8,
      Paint()..color = const Color(0xFFFFF7E0).withValues(alpha: alpha),
    );
  }

  /// A drop of water, falling point up.
  static void _droplet(Canvas canvas, Offset p, double r, double alpha) {
    final drop = Path()
      ..moveTo(p.dx, p.dy - r * 2.4)
      ..quadraticBezierTo(p.dx + r * 0.5, p.dy - r * 1.1, p.dx + r, p.dy)
      ..arcToPoint(Offset(p.dx - r, p.dy), radius: Radius.circular(r))
      ..quadraticBezierTo(p.dx - r * 0.5, p.dy - r * 1.1, p.dx, p.dy - r * 2.4)
      ..close();
    canvas.drawPath(
      drop,
      Paint()..color = const Color(0xFFF2FFFC).withValues(alpha: alpha * 0.9),
    );
    // A darker rim, so a drop shows on the light end of the room too.
    canvas.drawPath(
      drop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF0F766E).withValues(alpha: alpha * 0.45),
    );
    canvas.drawCircle(
      p.translate(-r * 0.35, -r * 0.2),
      r * 0.28,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
  }

  /// A bead of mist: a soft, small, bright dot.
  static void _bead(Canvas canvas, Offset p, double r, double alpha) {
    canvas.drawCircle(
      p,
      r * 2.2,
      Paint()
        ..color = const Color(0xFFD8F6FF).withValues(alpha: alpha * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.2),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
    );
  }

  /// A streak of wind from [from] towards [to], fading to its tail.
  static void _gust(Canvas canvas, Offset from, Offset to, double alpha) {
    final tailEnd = from - (to - from) * 1.6;
    canvas.drawLine(
      tailEnd,
      from,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8
        ..shader = ui.Gradient.linear(tailEnd, from, [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: alpha * 0.9),
        ]),
    );
  }

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

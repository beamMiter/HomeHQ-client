import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homehq/l10n/l10n.dart';
import 'package:homehq/models/appliance.dart';
import 'package:homehq/widgets/appliances/air_flow.dart';
import 'package:homehq/widgets/appliances/appliance_text.dart';
import 'package:homehq/widgets/appliances/cooler_hero.dart';
import 'package:homehq/widgets/appliances/heater_hero.dart';
import 'package:homehq/widgets/appliances/light_hero.dart';

Map<String, dynamic> _json({
  Object? status,
  bool online = true,
  bool on = true,
  Object? since,
  Object? autoOffAt,
  Object? checkedAt,
}) => {
  'id': 'X-0001',
  'name': 'Lamp',
  'kind': 'light',
  'online': online,
  'status': ?status,
  'checked_at': ?checkedAt,
  'since': ?since,
  'auto_off_at': ?autoOffAt,
  'capabilities': [
    {'key': 'power', 'type': 'bool'},
  ],
  'state': {'power': on},
};

/// Shows [child] 360 wide, in English, optionally asking for no animation.
Future<void> _show(
  WidgetTester t,
  Widget child, {
  bool reduceMotion = false,
  String locale = 'en',
}) => t.pumpWidget(
  MaterialApp(
    locale: Locale(locale),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: c!,
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  ),
);

Widget _light({bool on = true, int brightness = 60, bool offline = false}) =>
    LightHero(
      on: on,
      brightness: brightness,
      enabled: true,
      onPower: (_) {},
      offline: offline,
    );

Widget _cooler({
  bool on = true,
  int speed = 2,
  bool swing = false,
  bool cooling = false,
  String mode = 'normal',
}) => CoolerHero(
  on: on,
  speed: speed,
  swing: swing,
  cooling: cooling,
  mode: mode,
  enabled: true,
  onPower: (_) {},
);

void main() {
  group("an appliance's status from the server", () {
    test('reads the status and its times', () {
      final a = Appliance.fromJson(
        _json(
          status: 'on',
          checkedAt: '2026-10-16T14:00:05Z',
          since: '2026-10-16T12:00:00Z',
          autoOffAt: '2026-10-16T14:00:00Z',
        ),
      );
      expect(a.status, ApplianceStatus.on);
      expect(a.checkedAt, DateTime.utc(2026, 10, 16, 14, 0, 5));
      expect(a.since, DateTime.utc(2026, 10, 16, 12));
      expect(a.autoOffAt, DateTime.utc(2026, 10, 16, 14));
    });

    test('works it out the same way when the server does not say', () {
      expect(Appliance.fromJson(_json()).status, ApplianceStatus.on);
      expect(Appliance.fromJson(_json(on: false)).status, ApplianceStatus.off);
      expect(
        Appliance.fromJson(_json(online: false)).status,
        ApplianceStatus.offline,
      );
      expect(
        Appliance.fromJson(_json(status: 'sleeping', on: false)).status,
        ApplianceStatus.off,
        reason: 'a word this app does not know',
      );
    });

    test("Go's zero time means not known", () {
      final a = Appliance.fromJson(
        _json(checkedAt: '0001-01-01T00:00:00Z', since: 'not a time'),
      );
      expect(a.checkedAt, isNull);
      expect(a.since, isNull);
    });

    test('switching it drops "since"; adjusting it keeps it', () {
      final a = Appliance.fromJson(
        _json(
          status: 'on',
          since: '2026-10-16T12:00:00Z',
          autoOffAt: '2026-10-16T14:00:00Z',
        ),
      );
      final adjusted = a.withState({...a.state, 'brightness': 30});
      expect(adjusted.since, a.since);
      expect(adjusted.status, ApplianceStatus.on);

      final off = a.withState({...a.state, 'power': false});
      expect(off.status, ApplianceStatus.off);
      expect(off.since, isNull);
      expect(off.autoOffAt, isNull);
    });
  });

  group('a mode as a sign', () {
    test('every mode the server sends has one; an unknown one has none', () {
      for (final m in [
        'auto',
        'cool',
        'dry',
        'fan',
        'heat',
        'normal',
        'natural',
        'sleep',
      ]) {
        expect(modeIcon(m), isNotNull, reason: m);
      }
      expect(modeIcon('turbo'), isNull);
    });
  });

  group('the air', () {
    test('carries four values along its trip, smoothly between them', () {
      const k = AirKnots(0.2, 0.5, 0.4, 0.9);
      expect(k.at(0), closeTo(0.2, 1e-9));
      expect(k.at(1 / 3), closeTo(0.5, 1e-9));
      expect(k.at(2 / 3), closeTo(0.4, 1e-9));
      expect(k.at(1), closeTo(0.9, 1e-9));
      expect(k.at(-1), closeTo(0.2, 1e-9), reason: 'held at the ends');
      expect(k.at(2), closeTo(0.9, 1e-9));
      expect(k.max, 0.9);
      for (final t in [0.1, 0.5, 0.77]) {
        expect(const AirKnots.all(0.6).at(t), closeTo(0.6, 1e-9));
      }
    });

    test('takes the aim it left with: the shape changes along it', () {
      const steady = AirStream(0, 0, 50, 200, 0.4, 0);
      expect(steady.spreadAt(0.8), 0.4);
      expect(steady.lengthAt(0.8), 1.0);

      // Tipped up just now (wide, short), tipped down a moment ago.
      const turning = AirStream(
        0,
        0,
        50,
        200,
        0.7,
        0,
        spreads: AirKnots(0.7, 0.55, 0.4, 0.25),
        lengths: AirKnots(0.82, 0.88, 0.94, 1.0),
      );
      expect(turning.spreadAt(0), closeTo(0.7, 1e-9));
      expect(turning.spreadAt(1), closeTo(0.25, 1e-9));
      expect(turning.lengthAt(0), closeTo(0.82, 1e-9));
      expect(turning.lengthAt(1), closeTo(1.0, 1e-9));
      // Halfway along it is narrower than air that kept the new aim would be.
      final wide = const AirStream(0, 0, 50, 200, 0.7, 0).at(1, 0.5).dx;
      expect(turning.at(1, 0.5).dx, lessThan(wide));
      expect(turning.bounds.right, greaterThanOrEqualTo(turning.at(1, 1).dx));
    });
  });

  group('the drawn light', () {
    testWidgets('stands still while off: it asks for no frames', (t) async {
      await _show(t, _light(on: false));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(find.bySemanticsLabel('Light off'), findsOneWidget);
    });

    testWidgets('moves while on, and stops again once it is off', (t) async {
      await _show(t, _light());
      await t.pump(const Duration(milliseconds: 300));
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'dust drifts');
      expect(find.bySemanticsLabel('Light on, 60%'), findsOneWidget);

      await _show(t, _light(on: false));
      await t.pump(const Duration(milliseconds: 900));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('does not move when the system asks for no animation', (
      t,
    ) async {
      await _show(t, _light(), reduceMotion: true);
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('draws every brightness, and says it', (t) async {
      for (final b in [1, 25, 60, 100, 150, -5]) {
        await _show(t, _light(brightness: b));
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull, reason: 'brightness $b');
      }
      expect(find.bySemanticsLabel('Light on, 1%'), findsOneWidget);
    });

    testWidgets('veiled while offline, and says so', (t) async {
      await _show(t, _light(on: false, offline: true));
      await t.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('speaks Thai', (t) async {
      await _show(t, _light(brightness: 40), locale: 'th');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('ไฟเปิดอยู่ ความสว่าง 40%'), findsOneWidget);
    });
  });

  group('the drawn air cooler', () {
    testWidgets('stands still while off: it asks for no frames', (t) async {
      await _show(t, _cooler(on: false));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(find.bySemanticsLabel('Air cooler off'), findsOneWidget);
    });

    testWidgets('moves while on, and stops again once it is off', (t) async {
      await _show(t, _cooler(cooling: true));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.binding.hasScheduledFrame, isTrue);
      expect(
        find.bySemanticsLabel('Air cooler on, speed 2, cooling'),
        findsOneWidget,
      );

      await _show(t, _cooler(on: false));
      await t.pump(const Duration(milliseconds: 900));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('does not move when the system asks for no animation', (
      t,
    ) async {
      await _show(t, _cooler(swing: true), reduceMotion: true);
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    Future<void> everyWay(WidgetTester t) async {
      for (final mode in ['normal', 'natural', 'sleep', 'turbo']) {
        for (final speed in [1, 2, 3, 9]) {
          for (final swing in [false, true]) {
            for (final cooling in [false, true]) {
              await _show(
                t,
                _cooler(
                  mode: mode,
                  speed: speed,
                  swing: swing,
                  cooling: cooling,
                ),
              );
              await t.pump(const Duration(milliseconds: 200));
              expect(
                t.takeException(),
                isNull,
                reason: '$mode $speed swing $swing cooling $cooling',
              );
            }
          }
        }
      }
    }

    testWidgets('draws every setting without the shader', everyWay);

    testWidgets('draws every setting with the shader', (t) async {
      expect(await t.runAsync(loadAirShader), isNotNull);
      await everyWay(t);
    });

    testWidgets('says the speed without cooling', (t) async {
      await _show(t, _cooler(speed: 3));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.bySemanticsLabel('Air cooler on, speed 3'), findsOneWidget);
    });
  });

  group('the drawn heater', () {
    final now = DateTime(2026, 10, 16, 21, 0);
    Widget heater({bool on = true, bool countdown = true}) => HeaterHero(
      on: on,
      since: countdown ? now.subtract(const Duration(minutes: 71)) : null,
      autoOffAt: countdown ? now.add(const Duration(minutes: 49)) : null,
      enabled: true,
      onPower: (_) {},
      clock: () => now,
    );

    testWidgets('stands still while off: it asks for no frames', (t) async {
      await _show(t, heater(on: false));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(find.bySemanticsLabel('Heater off'), findsOneWidget);
    });

    testWidgets('warms up, and once off cools down and then stands still', (
      t,
    ) async {
      await _show(t, heater(on: false));
      await t.pumpAndSettle();
      await _show(t, heater());
      await t.pump(const Duration(seconds: 1));
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'warming up');
      await t.pump(const Duration(seconds: 3));
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'the air shimmers');

      await _show(t, heater(on: false));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'cooling down');
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('says when it switches itself off', (t) async {
      await _show(t, heater());
      await t.pump(const Duration(milliseconds: 300));
      expect(
        find.bySemanticsLabel('Heater on, switches itself off in 49 min'),
        findsOneWidget,
      );
      await _show(t, heater(countdown: false));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Heater on'), findsOneWidget);
    });

    testWidgets('does not move when the system asks for no animation', (
      t,
    ) async {
      await _show(t, heater(), reduceMotion: true);
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('draws with and without the shader, in Thai too', (t) async {
      for (final countdown in [false, true]) {
        await _show(t, heater(countdown: countdown));
        await t.pump(const Duration(seconds: 2));
        expect(t.takeException(), isNull);
      }
      expect(await t.runAsync(loadAirShader), isNotNull);
      await _show(t, heater(), locale: 'th');
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
      expect(
        find.bySemanticsLabel('ฮีตเตอร์เปิดอยู่ จะปิดเองในอีก 49 นาที'),
        findsOneWidget,
      );
    });
  });
}

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:homehq/l10n/l10n.dart';
import 'package:homehq/models/home_camera.dart';
import 'package:homehq/models/user.dart';
import 'package:homehq/models/weather.dart';
import 'package:homehq/repositories/cameras_repository.dart';
import 'package:homehq/screens/home_screen.dart';
import 'package:homehq/state/auth_state.dart';
import 'package:homehq/state/cameras_provider.dart';
import 'package:homehq/state/locale_provider.dart';
import 'package:homehq/state/weather_provider.dart';
import 'package:homehq/widgets/toast.dart';

/// Cameras as the server would list them; pictures never arrive.
class _Cameras extends CamerasRepository {
  _Cameras(
    this.cameras, {
    this.fail = false,
    this.pictureFails = false,
    this.noPictures = false,
  }) : super(Dio());
  final List<HomeCamera> cameras;
  final bool fail;
  final bool pictureFails;

  /// The server has no still picture to give (e.g. the demo cameras).
  final bool noPictures;

  @override
  Future<List<HomeCamera>> list({bool refresh = false}) async {
    if (fail) throw const CameraException(CameraFailure.disabled);
    return cameras;
  }

  @override
  Future<Uint8List> snapshot(String id) => noPictures
      ? Future.error(const CameraException(CameraFailure.unsupported))
      : pictureFails
      ? Future.error(const CameraException(CameraFailure.unavailable))
      : Completer<Uint8List>().future;
}

const _front = HomeCamera(id: 'front', name: 'Front door', online: true);
const _parcel = HomeCamera(id: 'parcel', name: 'Parcel spot', online: true);
const _yard = HomeCamera(id: 'yard', name: 'Back yard');

class _Auth extends AuthNotifier {
  _Auth(this.name);
  final String name;

  @override
  AuthState build() => AuthState(
    loading: false,
    isAuthenticated: true,
    user: User(id: '1', name: name, email: 'a@x.io'),
  );
}

// The tools, in the order they sit on the screen, with where each one goes.
const _tools = {
  'Home Cameras': '/cameras',
  'Contractors': '/contractors',
  'Home Appliances': '/appliances',
  'Important Notes': '/notes',
  'Spending Dashboard': '/dashboard',
  'Purchases': '/purchases',
  'Bills': '/bills',
  'Medicine Stock': '/medicine',
};

Future<void> _open(
  WidgetTester t, {
  String name = 'Somchai',
  Object? weatherError,
  double textScale = 1,
  Size size = const Size(390, 844),
  SharedPreferences? prefs,
  List<HomeCamera> cameras = const [],
  bool camerasFail = false,
  bool picturesFail = false,
  bool noPictures = false,
}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      for (final r in [..._tools.values, '/account', '/cameras/:id'])
        GoRoute(
          path: r,
          builder: (_, state) => Scaffold(body: Text('page ${state.uri}')),
        ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => _Auth(name)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        camerasRepoProvider.overrideWithValue(
          _Cameras(
            cameras,
            fail: camerasFail,
            pictureFails: picturesFail,
            noPictures: noPictures,
          ),
        ),
        currentWeatherProvider.overrideWith(
          (ref) async => weatherError != null
              ? throw weatherError
              : WeatherNow(
                  temperature: 31.4,
                  windSpeed: 3.2,
                  weatherCode: 2,
                  time: DateTime(2026, 10, 13, 14, 5),
                ),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp.router(
          scaffoldMessengerKey: AppToast.messengerKey,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    ),
  );
  // The tiles slide in; let that finish.
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('greeting', () {
    final en = l10nFor(const Locale('en')), th = l10nFor(const Locale('th'));

    test('follows the hour of the day', () {
      expect(homeGreeting(5, en), 'Good morning');
      expect(homeGreeting(11, en), 'Good morning');
      expect(homeGreeting(12, en), 'Good afternoon');
      expect(homeGreeting(16, en), 'Good afternoon');
      expect(homeGreeting(17, en), 'Good evening');
      expect(homeGreeting(20, en), 'Good evening');
      expect(homeGreeting(21, en), 'Hello');
      expect(homeGreeting(0, en), 'Hello');
      expect(homeGreeting(4, en), 'Hello');
    });

    test('is translated', () {
      expect(homeGreeting(9, th), 'สวัสดีตอนเช้า');
      expect(homeGreeting(14, th), 'สวัสดีตอนบ่าย');
      expect(homeGreeting(18, th), 'สวัสดีตอนเย็น');
      expect(homeGreeting(2, th), 'สวัสดี');
    });
  });

  group('cameras card', () {
    testWidgets('shows who is online and a picture per camera', (t) async {
      await _open(t, cameras: const [_front, _parcel, _yard]);
      expect(find.text('2 of 3 online'), findsOneWidget);
      expect(find.text('Front door'), findsOneWidget);
      expect(find.text('Parcel spot'), findsOneWidget);
      expect(find.text('Back yard'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      // The caption gives way to the live summary.
      expect(find.text('Watch the home cameras'), findsNothing);
    });

    testWidgets('a picture on its way shows a plain camera', (t) async {
      await _open(t, cameras: const [_front, _parcel, _yard]);
      expect(find.byIcon(Icons.videocam_rounded), findsNWidgets(2));
      // Only the offline one has a cross so far.
      expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);
    });

    testWidgets('cameras with no still picture keep a plain camera cover', (
      t,
    ) async {
      await _open(t, cameras: const [_front, _parcel, _yard], noPictures: true);
      // Not a failure: a camera, not a crossed one (only Back yard is offline).
      expect(find.byIcon(Icons.videocam_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('a picture that cannot be loaded shows a crossed camera', (
      t,
    ) async {
      await _open(
        t,
        cameras: const [_front, _parcel, _yard],
        picturesFail: true,
      );
      // Front door, Parcel spot (no picture) and Back yard (offline).
      expect(find.byIcon(Icons.videocam_off_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
      // Only the offline one says so in words.
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('a picture opens that camera', (t) async {
      await _open(t, cameras: const [_front, _parcel, _yard]);
      await t.tap(find.text('Parcel spot'));
      await t.pumpAndSettle();
      expect(find.text('page /cameras/parcel'), findsOneWidget);
    });

    testWidgets('an offline camera says so instead of opening', (t) async {
      await _open(t, cameras: const [_front, _parcel, _yard]);
      await t.tap(find.text('Back yard'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('This camera is offline right now'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('more than three: the last picture leads to all', (t) async {
      await _open(
        t,
        cameras: [
          _front,
          _parcel,
          for (var i = 0; i < 3; i++)
            HomeCamera(id: 'c$i', name: 'Cam $i', online: true),
        ],
      );
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('Cam 1'), findsNothing);
      await t.tap(find.text('+2'));
      await t.pumpAndSettle();
      expect(find.text('page /cameras'), findsOneWidget);
    });

    testWidgets('nothing online shows a grey dot and the count', (t) async {
      await _open(t, cameras: const [_yard]);
      expect(find.text('0 of 1 online'), findsOneWidget);
    });

    testWidgets('without cameras it is the plain card', (t) async {
      await _open(t, camerasFail: true);
      expect(find.text('Watch the home cameras'), findsOneWidget);
      expect(find.textContaining('online'), findsNothing);
      await t.tap(find.text('Home Cameras'));
      await t.pumpAndSettle();
      expect(find.text('page /cameras'), findsOneWidget);
    });

    testWidgets('fits a small phone with large text', (t) async {
      await _open(
        t,
        cameras: const [_front, _parcel, _yard],
        textScale: 1.2,
        size: const Size(320, 640),
      );
      expect(t.takeException(), isNull);
    });
  });

  group('header', () {
    testWidgets('does not move with the page', (t) async {
      await _open(t);
      final before = t.getTopLeft(find.text('Somchai'));
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(120);
      await t.pump();
      final after = t.getTopLeft(find.text('Somchai'));
      // It scrolls away with the page, exactly as far: no slower drift.
      expect(before.dy - after.dy, closeTo(120, 1));
    });
  });

  group('home screen', () {
    testWidgets('greets the user and shows the weather', (t) async {
      await _open(t);

      expect(find.text('Somchai'), findsOneWidget);
      expect(find.text('31°C'), findsOneWidget);
      expect(find.text('Partly cloudy'), findsOneWidget);
      expect(find.textContaining('3.2 m/s'), findsOneWidget);
      expect(find.textContaining('14:05'), findsOneWidget);
    });

    testWidgets('the avatar opens the account page', (t) async {
      await _open(t, name: 'Somchai Jaidee');
      expect(find.text('SJ'), findsOneWidget);
      await t.tap(find.byTooltip('Open your account'));
      await t.pumpAndSettle();
      expect(find.text('page /account'), findsOneWidget);
    });

    testWidgets('the header shows no app name and no sign-out', (t) async {
      await _open(t);
      expect(find.text('HOMESERVICE'), findsNothing);
      expect(find.byTooltip('Log out'), findsNothing);
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });

    testWidgets('works without a name', (t) async {
      await _open(t, name: '');
      // No empty line where the name would be; the greeting is still there.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Somchai'), findsNothing);
    });

    testWidgets('a weather failure stays inside the header', (t) async {
      await _open(t, weatherError: StateError('no gps'));

      expect(find.text("Couldn't load the weather"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // The tools are still there and usable.
      expect(find.text('Home Cameras'), findsOneWidget);
    });

    testWidgets('shows every tool with its English name', (t) async {
      await _open(t);
      for (final name in _tools.keys) {
        await t.scrollUntilVisible(
          find.text(name),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(name), findsOneWidget, reason: name);
      }
    });

    testWidgets('contractors and appliances share a row, the rest are wide', (
      t,
    ) async {
      await _open(t);
      Size tile(String name) => t.getSize(
        find
            .ancestor(of: find.text(name), matching: find.byType(Material))
            .first,
      );
      final contractors = t.getTopLeft(find.text('Contractors'));
      final appliances = t.getTopLeft(find.text('Home Appliances'));
      expect(appliances.dy, contractors.dy, reason: 'same row');
      expect(
        appliances.dx,
        greaterThan(contractors.dx),
        reason: 'on the right',
      );

      // Half the width each...
      final half = tile('Contractors').width;
      expect(tile('Home Appliances').width, half);
      // ...and every other tool is a full-width card, in this order, below.
      var above = appliances.dy;
      for (final name in [
        'Important Notes',
        'Spending Dashboard',
        'Purchases',
        'Bills',
        'Medicine Stock',
      ]) {
        expect(tile(name).width, greaterThan(half * 1.8), reason: name);
        final y = t.getTopLeft(find.text(name)).dy;
        expect(y, greaterThan(above), reason: '$name sits below the previous');
        above = y;
      }
    });

    for (final e in _tools.entries) {
      testWidgets('${e.key} opens ${e.value}', (t) async {
        await _open(t);
        await t.scrollUntilVisible(
          find.text(e.key),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.ensureVisible(find.text(e.key));
        await t.pumpAndSettle();
        await t.tap(find.text(e.key));
        await t.pumpAndSettle();

        expect(find.text('page ${e.value}'), findsOneWidget);
      });
    }

    testWidgets('the tool opened last is marked, and stays marked', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await _open(t, prefs: prefs);
      expect(find.text('Last used'), findsNothing);

      await t.ensureVisible(find.text('Bills'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bills'));
      await t.pumpAndSettle();
      GoRouter.of(t.element(find.text('page /bills'))).pop();
      await t.pumpAndSettle();

      final billsTile = find.ancestor(
        of: find.text('Bills'),
        matching: find.byType(Material),
      );
      expect(
        find.descendant(of: billsTile.first, matching: find.text('Last used')),
        findsOneWidget,
      );
      expect(find.text('Last used'), findsOneWidget);
      expect(prefs.getString('home_last_tool'), '/bills');
    });

    testWidgets('a saved last tool is marked on start', (t) async {
      SharedPreferences.setMockInitialValues({'home_last_tool': '/notes'});
      await _open(t, prefs: await SharedPreferences.getInstance());
      final notesTile = find.ancestor(
        of: find.text('Important Notes'),
        matching: find.byType(Material),
      );
      expect(
        find.descendant(of: notesTile.first, matching: find.text('Last used')),
        findsOneWidget,
      );
    });

    testWidgets('pressing a tile tilts it, letting go puts it back', (t) async {
      await _open(t);
      // The tilt is the only transform with rotation in it.
      bool tilted() => t
          .widgetList<Transform>(find.byType(Transform))
          .any(
            (w) => w.transform.entry(0, 2) != 0 || w.transform.entry(1, 2) != 0,
          );
      expect(tilted(), isFalse);

      final g = await t.startGesture(t.getTopLeft(find.text('Contractors')));
      await t.pump(); // takes the touch
      await t.pump(const Duration(milliseconds: 300)); // leans
      expect(tilted(), isTrue);

      await g.cancel();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(tilted(), isFalse);
    });

    testWidgets('scrolling that starts on a tile does not tilt it', (t) async {
      await _open(t);
      bool tilted() => t
          .widgetList<Transform>(find.byType(Transform))
          .any(
            (w) => w.transform.entry(0, 2) != 0 || w.transform.entry(1, 2) != 0,
          );

      final g = await t.startGesture(t.getCenter(find.text('Contractors')));
      await t.pump();
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(0, -20));
        await t.pump(const Duration(milliseconds: 16));
      }
      await t.pump(const Duration(milliseconds: 300));
      expect(tilted(), isFalse);
      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('searching goes to contractors with the query', (t) async {
      await _open(t);
      await t.enterText(find.byType(TextField), 'plumber');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();

      expect(find.text('page /contractors?q=plumber'), findsOneWidget);
    });

    testWidgets('nothing overflows on a small phone with large text', (
      t,
    ) async {
      await _open(
        t,
        name: 'A rather long display name for a person',
        textScale: 1.2,
        size: const Size(320, 640),
      );
      // A RenderFlex overflow would have been reported as a test exception.
      expect(t.takeException(), isNull);

      await t.scrollUntilVisible(
        find.text('Medicine Stock'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(t.takeException(), isNull);
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'package:homeservice/l10n/l10n.dart';
import 'package:homeservice/models/home_camera.dart';
import 'package:homeservice/repositories/cameras_repository.dart';
import 'package:homeservice/screens/camera_player_screen.dart';
import 'package:homeservice/screens/cameras_screen.dart';
import 'package:homeservice/state/cameras_provider.dart';
import 'package:homeservice/state/screen_awake.dart';
import 'package:homeservice/widgets/page_loading.dart';
import 'package:homeservice/widgets/refresh.dart';
import 'package:homeservice/widgets/toast.dart';

// A 1x1 PNG, so Image.memory has something valid to decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

const _front = HomeCamera(
  id: 'FRONT-0001',
  name: 'Front door',
  online: true,
  humanDetect: true,
  ptz: true,
  zoom: true,
  switches: ['privacy', 'motion', 'human', 'light', 'light_auto'],
);
const _parcel = HomeCamera(
  id: 'PARCEL-001',
  name: 'Parcel spot',
  online: true,
  switches: ['motion', 'human'],
);
const _yard = HomeCamera(id: 'YARD-00001', name: 'Back yard', online: false);

/// Camera repository that records what it was asked and can be steered.
class _FakeCameras extends CamerasRepository {
  _FakeCameras({
    this.enabled = true,
    this.cameras = const [_front, _parcel, _yard],
    this.listError,
    this.liveError,
  }) : super(Dio());

  bool enabled;
  List<HomeCamera> cameras;
  CameraException? listError;
  CameraException? liveError;

  int statusCalls = 0;
  final List<bool> listRefreshFlags = [];
  final List<String> liveRequests = []; // "id|quality"
  final List<String> snapshotRequests = [];

  // "<id> <action> <ms or ->" for every turn command, in order.
  final List<String> ptzCalls = [];
  CameraException? ptzError;

  // "<id> <key> <on>" for every setting change.
  final List<String> setCalls = [];
  final Map<String, bool> switchState = {};
  bool failSwitchWrites = false;

  /// While set, the next list() waits for it.
  Completer<void>? holdList;

  @override
  Future<CamerasStatus?> status() async {
    statusCalls++;
    return CamerasStatus(enabled: enabled, driver: 'fake');
  }

  @override
  Future<List<HomeCamera>> list({bool refresh = false}) async {
    listRefreshFlags.add(refresh);
    await holdList?.future;
    final e = listError;
    if (e != null) throw e;
    return cameras;
  }

  @override
  Future<CameraLive> live(String id, {String quality = 'hd'}) async {
    liveRequests.add('$id|$quality');
    final e = liveError;
    if (e != null) throw e;
    return CameraLive(
      url: 'https://cdn.example/$id/$quality.m3u8',
      quality: quality,
    );
  }

  @override
  Future<void> ptz(String id, String action, {int? durationMs}) async {
    ptzCalls.add('$id $action ${durationMs ?? '-'}');
    final e = ptzError;
    if (e != null) throw e;
  }

  @override
  Future<Map<String, bool>> switches(String id) async {
    final cam = cameras.firstWhere((c) => c.id == id);
    return {
      for (final k in cam.switches)
        k: switchState['$id/$k'] ?? (k == 'motion' || k == 'human'),
    };
  }

  @override
  Future<void> setSwitch(String id, String key, bool on) async {
    setCalls.add('$id $key $on');
    if (failSwitchWrites) {
      throw const CameraException(CameraFailure.unavailable);
    }
    switchState['$id/$key'] = on;
  }

  @override
  Future<Uint8List> snapshot(String id) async {
    snapshotRequests.add(id);
    return _png;
  }
}

/// Records whether the screen is being held on.
class _FakeAwake implements ScreenAwake {
  final List<bool> holds = [];
  bool get on => holds.isNotEmpty && holds.last;

  @override
  Future<void> hold(bool on) async => holds.add(on);
}

/// A player that never touches the platform plugin.
class _FakeController extends VideoPlayerController {
  // ignore: use_super_parameters
  _FakeController(Uri uri, {this.failInit = false, this.hold})
    : super.networkUrl(uri);

  final bool failInit;

  /// While set, opening the stream waits for it (a slow connection).
  final Completer<void>? hold;
  bool played = false;
  bool pausedCalled = false;
  double volumeSet = 1;
  bool disposedCalled = false;

  @override
  Future<void> initialize() async {
    await hold?.future;
    if (failInit) throw Exception('cannot open stream');
    value = value.copyWith(
      isInitialized: true,
      size: const Size(640, 360),
      duration: const Duration(minutes: 1),
    );
  }

  @override
  Future<void> play() async {
    played = true;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pausedCalled = true;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeSet = volume;
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> dispose() async {
    disposedCalled = true;
    await super.dispose();
  }
}

Future<void> _frames(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  WidgetTester t,
  _FakeCameras repo, {
  String locale = 'th',
  List<_FakeController>? controllers,
  _FakeAwake? awake,
  bool failPlayer = false,
  Completer<void>? holdPlayer,
  String initial = '/cameras',
  Size size = const Size(800, 1600),
  double textScale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/cameras',
        builder: (_, __) => const CamerasScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, st) => CameraPlayerScreen(
              id: st.pathParameters['id']!,
              camera: st.extra is HomeCamera ? st.extra as HomeCamera : null,
              idleLimit: const Duration(seconds: 3),
            ),
          ),
        ],
      ),
    ],
  );

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        camerasRepoProvider.overrideWithValue(repo),
        screenAwakeProvider.overrideWithValue(awake ?? _FakeAwake()),
        videoControllerFactoryProvider.overrideWithValue((uri) {
          final c = _FakeController(
            uri,
            failInit: failPlayer,
            hold: holdPlayer,
          );
          controllers?.add(c);
          return c;
        }),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        scaffoldMessengerKey: AppToast.messengerKey,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await _frames(t);
}

void main() {
  group('camera grid', () {
    testWidgets('shows each camera with its state', (t) async {
      final repo = _FakeCameras();
      await _open(t, repo, locale: 'en');

      expect(find.text('Front door'), findsOneWidget);
      expect(find.text('Parcel spot'), findsOneWidget);
      expect(find.text('Back yard'), findsOneWidget);
      // The offline one says so instead of showing a picture.
      expect(find.text('Offline'), findsOneWidget);
      // Pictures are asked for only for cameras that are online.
      expect(repo.snapshotRequests.toSet(), {'FRONT-0001', 'PARCEL-001'});
      expect(find.byType(Image), findsNWidgets(2));
      // A person icon only where the camera itself detects people.
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('says when cameras are not set up on the server', (t) async {
      final repo = _FakeCameras(enabled: false);
      await _open(t, repo, locale: 'en');

      expect(find.text("Cameras aren't set up yet"), findsOneWidget);
      expect(repo.listRefreshFlags, isEmpty, reason: 'must not ask for a list');
    });

    testWidgets('an empty account has its own message', (t) async {
      await _open(t, _FakeCameras(cameras: const []), locale: 'en');
      expect(find.text('No cameras found'), findsOneWidget);
    });

    testWidgets('failures are worded, not dumped', (t) async {
      await _open(
        t,
        _FakeCameras(listError: const CameraException(CameraFailure.limited)),
        locale: 'en',
      );
      expect(
        find.text(
          'The camera service has reached its call limit. Try again later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping an offline camera explains instead of opening it', (
      t,
    ) async {
      await _open(t, _FakeCameras(), locale: 'en');
      await t.tap(find.text('Back yard'));
      await _frames(t, 3);

      expect(find.text('This camera is offline right now'), findsOneWidget);
      expect(find.byType(CameraPlayerScreen), findsNothing);
    });

    testWidgets('the refresh button shows the loading page and re-asks fresh', (
      t,
    ) async {
      final repo = _FakeCameras();
      await _open(t, repo, locale: 'en');
      expect(repo.listRefreshFlags, [false]);

      final hold = Completer<void>();
      repo.holdList = hold;
      await t.tap(find.byTooltip('Refresh'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(PageLoading), findsOneWidget);

      hold.complete();
      await _frames(t, 8);
      expect(find.byType(PageLoading), findsNothing);
      // The refresh went to the server asking it to skip its cache.
      expect(repo.listRefreshFlags.last, isTrue);
      // Pictures are fetched again, not reused.
      expect(repo.snapshotRequests.length, greaterThan(2));
      await t.pump(kMinReloadLoader);
    });

    testWidgets('fits a small phone with large text and long names', (t) async {
      final repo = _FakeCameras(
        cameras: const [
          HomeCamera(
            id: 'LONG-0001',
            name: 'Front door camera facing the street and the parcel shelf',
            online: true,
            humanDetect: true,
          ),
          _yard,
          _parcel,
        ],
      );
      // 320 x 640 logical px, text at the app's 1.2x ceiling.
      await _open(
        t,
        repo,
        locale: 'en',
        size: const Size(640, 1280),
        textScale: 1.2,
      );
      expect(
        t.takeException(),
        isNull,
        reason: 'no overflow on a small screen',
      );
      expect(find.textContaining('Front door camera'), findsOneWidget);
    });

    testWidgets('the card you tap to open a camera has square corners', (
      t,
    ) async {
      await _open(t, _FakeCameras(), locale: 'en');
      final card = t.widget<Material>(
        find
            .ancestor(
              of: find.text('Front door'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.borderRadius, isNull);
      expect(card.shape, isNull, reason: 'no rounded shape on the card');
    });

    testWidgets('English UI has no Thai in it', (t) async {
      await _open(t, _FakeCameras(), locale: 'en');
      final thai = RegExp(r'[฀-฾เ-๿]');
      final bad = [
        for (final e in find.byType(Text).evaluate())
          if (thai.hasMatch((e.widget as Text).data ?? ''))
            (e.widget as Text).data,
      ];
      expect(bad, isEmpty);
    });
  });

  group('player', () {
    testWidgets('opens the camera, plays it, shows LIVE', (t) async {
      final repo = _FakeCameras();
      final controllers = <_FakeController>[];
      await _open(t, repo, locale: 'en', controllers: controllers);

      await t.tap(find.text('Front door'));
      await _frames(t);

      expect(find.byType(CameraPlayerScreen), findsOneWidget);
      expect(repo.liveRequests, ['FRONT-0001|hd']);
      expect(controllers, hasLength(1));
      expect(controllers.single.played, isTrue);
      expect(
        controllers.single.dataSource,
        'https://cdn.example/FRONT-0001/hd.m3u8',
      );
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets(
      'switching to SD asks for the SD stream and closes the old one',
      (t) async {
        final repo = _FakeCameras();
        final controllers = <_FakeController>[];
        await _open(t, repo, locale: 'en', controllers: controllers);
        await t.tap(find.text('Front door'));
        await _frames(t);

        await t.tap(find.text('HD'));
        await t.pumpAndSettle();
        await t.tap(find.text('SD').last);
        await _frames(t);

        expect(repo.liveRequests, ['FRONT-0001|hd', 'FRONT-0001|sd']);
        expect(controllers, hasLength(2));
        expect(controllers.first.disposedCalled, isTrue);
        expect(controllers.last.dataSource, endsWith('/sd.m3u8'));
      },
    );

    testWidgets('muting sets the volume to zero', (t) async {
      final controllers = <_FakeController>[];
      await _open(t, _FakeCameras(), locale: 'en', controllers: controllers);
      await t.tap(find.text('Front door'));
      await _frames(t);

      await t.tap(find.byTooltip('Mute'));
      await t.pump();
      expect(controllers.single.volumeSet, 0);
      expect(find.byTooltip('Unmute'), findsOneWidget);
    });

    testWidgets('while connecting it is just the spinner and the words', (
      t,
    ) async {
      final hold = Completer<void>();
      await _open(t, _FakeCameras(), locale: 'en', holdPlayer: hold);
      await t.tap(find.text('Front door'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));

      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      // No camera drawn in the block with the words.
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Connecting…'),
                matching: find.byType(Column),
              )
              .first,
          matching: find.byType(Icon),
        ),
        findsNothing,
      );

      hold.complete();
      await _frames(t);
    });

    testWidgets('a stream that will not open shows a crossed camera', (
      t,
    ) async {
      await _open(t, _FakeCameras(), locale: 'en', failPlayer: true);
      await t.tap(find.text('Front door'));
      await _frames(t);

      expect(find.text("Couldn't play the stream"), findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text("Couldn't play the stream"),
                matching: find.byType(Column),
              )
              .first,
          matching: find.byIcon(Icons.videocam_off_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a stream that will not open can be retried', (t) async {
      final repo = _FakeCameras();
      final controllers = <_FakeController>[];
      await _open(
        t,
        repo,
        locale: 'en',
        controllers: controllers,
        failPlayer: true,
      );
      await t.tap(find.text('Front door'));
      await _frames(t);

      expect(find.text("Couldn't play the stream"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await t.tap(find.text('Try again'));
      await _frames(t);
      // Every attempt asks the server for a fresh address.
      expect(repo.liveRequests.length, 2);
    });

    testWidgets('a server-side refusal is worded', (t) async {
      await _open(
        t,
        _FakeCameras(liveError: const CameraException(CameraFailure.offline)),
        locale: 'en',
      );
      await t.tap(find.text('Front door'));
      await _frames(t);
      expect(find.text('The camera is offline'), findsOneWidget);
    });

    testWidgets('pauses itself when left running, and can resume', (t) async {
      final controllers = <_FakeController>[];
      await _open(t, _FakeCameras(), locale: 'en', controllers: controllers);
      await t.tap(find.text('Front door'));
      await _frames(t);
      expect(find.text('Paused to save data'), findsNothing);

      await t.pump(const Duration(seconds: 4)); // past the 3 s test limit
      expect(controllers.single.pausedCalled, isTrue);
      expect(find.text('Paused to save data'), findsOneWidget);

      await t.tap(find.text('Resume'));
      await t.pump();
      expect(find.text('Paused to save data'), findsNothing);
      expect(find.text('LIVE'), findsOneWidget);

      // let the new idle timer finish so the test ends clean
      await t.pump(const Duration(seconds: 4));
    });

    testWidgets('leaving the screen disposes the player', (t) async {
      final controllers = <_FakeController>[];
      await _open(t, _FakeCameras(), locale: 'en', controllers: controllers);
      await t.tap(find.text('Front door'));
      await _frames(t);

      await t.tap(find.byTooltip('Back'));
      await _frames(t);
      expect(controllers.single.disposedCalled, isTrue);
    });
  });

  group('moving between cameras', () {
    testWidgets('swiping goes to the next camera and streams it', (t) async {
      final repo = _FakeCameras();
      final controllers = <_FakeController>[];
      await _open(t, repo, locale: 'en', controllers: controllers);
      await t.tap(find.text('Front door').first);
      await _frames(t);
      expect(repo.liveRequests, ['FRONT-0001|hd']);
      expect(find.text('1 of 2'), findsOneWidget); // the offline one is skipped

      await t.fling(find.byType(PageView), const Offset(-500, 0), 1500);
      await _frames(t, 10);

      expect(repo.liveRequests, ['FRONT-0001|hd', 'PARCEL-001|hd']);
      expect(controllers, hasLength(2));
      expect(controllers.first.disposedCalled, isTrue);
      expect(find.text('Parcel spot'), findsWidgets);
      expect(find.text('2 of 2'), findsOneWidget);
    });

    testWidgets('tapping a camera in the strip jumps to it', (t) async {
      final repo = _FakeCameras();
      await _open(t, repo, locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);

      await t.tap(find.byKey(const ValueKey('strip-PARCEL-001')));
      await _frames(t, 10);
      expect(repo.liveRequests.last, 'PARCEL-001|hd');

      // an offline camera is explained, not opened
      await t.tap(find.byKey(const ValueKey('strip-YARD-00001')));
      await _frames(t, 3);
      expect(find.text('This camera is offline right now'), findsOneWidget);
      expect(repo.liveRequests.last, 'PARCEL-001|hd');
    });

    testWidgets('only the camera on screen is streamed', (t) async {
      final repo = _FakeCameras();
      final controllers = <_FakeController>[];
      await _open(t, repo, locale: 'en', controllers: controllers);
      await t.tap(find.text('Front door').first);
      await _frames(t);
      expect(controllers, hasLength(1));
      expect(repo.liveRequests, hasLength(1));
    });
  });

  group('turning the camera', () {
    Future<void> openFront(WidgetTester t, _FakeCameras repo) async {
      await _open(t, repo, locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);
    }

    testWidgets('the pad only appears for a camera that can turn', (t) async {
      final repo = _FakeCameras();
      await openFront(t, repo);
      expect(find.byKey(const ValueKey('ptz-left')), findsOneWidget);
      // this one also has an optical zoom
      expect(find.byKey(const ValueKey('ptz-zoom_in')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('strip-PARCEL-001')));
      await _frames(t, 10);
      expect(find.byKey(const ValueKey('ptz-left')), findsNothing);
      expect(find.byKey(const ValueKey('ptz-zoom_in')), findsNothing);
    });

    testWidgets('holding moves, letting go stops', (t) async {
      final repo = _FakeCameras();
      await openFront(t, repo);

      final left = find.byKey(const ValueKey('ptz-left'));
      final g = await t.startGesture(t.getCenter(left));
      await t.pump();
      expect(repo.ptzCalls, ['FRONT-0001 left 1500']);

      // still held: it keeps going, re-issuing before the move runs out
      await t.pump(const Duration(milliseconds: 1400));
      expect(repo.ptzCalls.length, 2);
      expect(repo.ptzCalls.last, 'FRONT-0001 left 1500');

      await g.up();
      await t.pump();
      expect(repo.ptzCalls.last, 'FRONT-0001 stop -');
      final settled = repo.ptzCalls.length;

      // nothing more is sent once released
      await t.pump(const Duration(seconds: 3));
      expect(repo.ptzCalls.length, settled);
    });

    testWidgets('a quick tap is a move then a stop, in that order', (t) async {
      final repo = _FakeCameras();
      await openFront(t, repo);

      await t.tap(find.byKey(const ValueKey('ptz-up')));
      await t.pump();
      expect(repo.ptzCalls, ['FRONT-0001 up 1500', 'FRONT-0001 stop -']);
    });

    testWidgets('zoom uses the same hold-to-move', (t) async {
      final repo = _FakeCameras();
      await openFront(t, repo);
      await t.tap(find.byKey(const ValueKey('ptz-zoom_out')));
      await t.pump();
      expect(repo.ptzCalls.first, 'FRONT-0001 zoom_out 1500');
    });

    testWidgets('a camera that refuses is reported', (t) async {
      final repo = _FakeCameras()
        ..ptzError = const CameraException(CameraFailure.offline);
      await openFront(t, repo);
      await t.tap(find.byKey(const ValueKey('ptz-right')));
      await _frames(t, 3);
      expect(find.text('The camera is offline'), findsOneWidget);
    });

    testWidgets('leaving while held stops the camera', (t) async {
      final repo = _FakeCameras();
      await openFront(t, repo);
      final g = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('ptz-down'))),
      );
      await t.pump();

      await t.pumpWidget(const SizedBox()); // the screen goes away mid-hold
      await t.pump();
      expect(repo.ptzCalls.last, 'FRONT-0001 stop -');
      await g.up();
    });
  });

  group('camera settings', () {
    Future<void> openFront(WidgetTester t, _FakeCameras repo) async {
      await _open(t, repo, locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);
    }

    testWidgets('shows only the settings the camera has, with their state', (
      t,
    ) async {
      final repo = _FakeCameras();
      await openFront(t, repo);
      await t.ensureVisible(find.text('Person detection'));

      expect(find.text('Privacy mode'), findsOneWidget);
      expect(find.text('Motion detection'), findsOneWidget);
      expect(find.text('Person detection'), findsOneWidget);
      final privacy = t.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Privacy mode'),
      );
      expect(privacy.value, isFalse);
      final motion = t.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Motion detection'),
      );
      expect(motion.value, isTrue);

      // the parcel camera has no privacy mode
      await t.tap(find.byKey(const ValueKey('strip-PARCEL-001')));
      await _frames(t, 10);
      expect(find.text('Privacy mode'), findsNothing);
      expect(find.text('Motion detection'), findsOneWidget);
    });

    testWidgets('flipping a setting sends it and shows it at once', (t) async {
      final repo = _FakeCameras();
      await openFront(t, repo);
      await t.ensureVisible(find.text('Motion detection'));
      await t.pump();

      await t.tap(find.text('Motion detection'));
      await t.pump();
      expect(repo.setCalls, ['FRONT-0001 motion false']);
      final motion = t.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Motion detection'),
      );
      expect(motion.value, isFalse);
    });

    testWidgets(
      'the camera light is a setting, and a button over the picture',
      (t) async {
        final repo = _FakeCameras();
        await openFront(t, repo);

        // the button over the picture
        final lightBtn = find.byTooltip('Camera light');
        expect(lightBtn, findsOneWidget);
        expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

        await t.tap(lightBtn);
        await t.pump();
        expect(repo.setCalls, ['FRONT-0001 light true']);
        expect(find.byIcon(Icons.lightbulb_rounded), findsWidgets);

        // the same state shows in the settings card: they cannot disagree
        await t.ensureVisible(find.text('Light on motion'));
        await t.pump();
        final tile = t.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Camera light'),
        );
        expect(tile.value, isTrue);

        // and the other way round: flipping it in the card updates the button
        await t.tap(find.text('Camera light'));
        await t.pump();
        expect(repo.setCalls.last, 'FRONT-0001 light false');
        expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
      },
    );

    testWidgets('no light button on a camera without a light', (t) async {
      final repo = _FakeCameras();
      await openFront(t, repo);
      await t.tap(find.byKey(const ValueKey('strip-PARCEL-001')));
      await _frames(t, 10);
      expect(find.byTooltip('Camera light'), findsNothing);
      expect(find.text('Light on motion'), findsNothing);
    });

    testWidgets('a light that will not switch is undone and reported', (
      t,
    ) async {
      final repo = _FakeCameras()..failSwitchWrites = true;
      await openFront(t, repo);
      await t.tap(find.byTooltip('Camera light'));
      await _frames(t, 3);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
      expect(find.text("Couldn't change the setting"), findsOneWidget);
    });

    testWidgets('a failed change is undone and reported', (t) async {
      final repo = _FakeCameras()..failSwitchWrites = true;
      await openFront(t, repo);
      await t.ensureVisible(find.text('Motion detection'));
      await t.pump();

      await t.tap(find.text('Motion detection'));
      await _frames(t, 3);
      final motion = t.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Motion detection'),
      );
      expect(motion.value, isTrue, reason: 'back to what it was');
      expect(find.text("Couldn't change the setting"), findsOneWidget);
    });
  });

  group('full screen', () {
    /// Records the orientation requests the screen makes.
    List<MethodCall> recordPlatform(WidgetTester t) {
      final calls = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return calls;
    }

    Iterable<String> orientations(List<MethodCall> calls) => calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .map((c) => c.arguments.toString());

    testWidgets('hides the panel and rotates to landscape', (t) async {
      final calls = recordPlatform(t);
      await _open(t, _FakeCameras(), locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);
      expect(find.text('Cameras'), findsOneWidget); // the strip's heading

      await t.tap(find.byTooltip('Full screen'));
      await _frames(t, 3);
      expect(find.text('Cameras'), findsNothing);
      // the small pad stays reachable over the picture
      expect(find.byKey(const ValueKey('ptz-left')), findsOneWidget);
      expect(
        orientations(calls).last,
        contains('DeviceOrientation.landscapeLeft'),
      );

      // leave it, and let the "free the orientation" pause run out
      await t.tap(find.byTooltip('Exit full screen'));
      await t.pump(const Duration(milliseconds: 700));
    });

    testWidgets('leaving it turns the screen back to portrait', (t) async {
      final calls = recordPlatform(t);
      await _open(t, _FakeCameras(), locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);
      await t.tap(find.byTooltip('Full screen'));
      await _frames(t, 3);

      await t.tap(find.byTooltip('Exit full screen'));
      await t.pump();
      // An empty list does not turn a landscape screen upright on iOS; portrait
      // has to be asked for by name.
      expect(
        orientations(calls).last,
        contains('DeviceOrientation.portraitUp'),
        reason: 'must be forced upright, not merely "handed back"',
      );
      expect(find.text('Cameras'), findsOneWidget, reason: 'panel is back');

      // It must STAY upright: freeing it would let a phone still held
      // sideways swing straight back to landscape (the "doubling" bug).
      final before = orientations(calls).length;
      await t.pump(const Duration(seconds: 2));
      expect(orientations(calls).length, before, reason: 'no further change');
      expect(
        orientations(calls).last,
        contains('DeviceOrientation.portraitUp'),
      );

      // Leaving the player keeps it upright too: it is NOT handed back to the
      // system, which would let a tilted phone swing the whole app sideways.
      await t.tap(find.byTooltip('Back'));
      await _frames(t, 8); // the page's exit transition, then it is disposed
      expect(
        orientations(calls).last,
        contains('DeviceOrientation.portraitUp'),
      );
      expect(orientations(calls), isNot(contains('[]')));
    });

    testWidgets('leaving the player never frees the orientation, even if '
        'full screen was never used', (t) async {
      final calls = recordPlatform(t);
      await _open(t, _FakeCameras(), locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);

      await t.tap(find.byTooltip('Back'));
      await _frames(t, 8);
      expect(find.byType(CameraPlayerScreen), findsNothing);
      expect(
        orientations(calls).last,
        contains('DeviceOrientation.portraitUp'),
        reason: 'back on the cameras page the app must stay upright',
      );
      expect(orientations(calls), isNot(contains('[]')));
    });

    testWidgets('entering full screen again after leaving it works', (t) async {
      final calls = recordPlatform(t);
      await _open(t, _FakeCameras(), locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);

      await t.tap(find.byTooltip('Full screen'));
      await _frames(t, 2);
      await t.tap(find.byTooltip('Exit full screen'));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.byTooltip('Full screen')); // quickly again
      await t.pump(const Duration(milliseconds: 700));

      expect(
        orientations(calls).last,
        contains('DeviceOrientation.landscapeLeft'),
      );
      expect(
        orientations(calls),
        isNot(contains('[]')),
        reason: 'nothing may free the orientation while the player is open',
      );
      // finish cleanly
      await t.tap(find.byTooltip('Exit full screen'));
      await t.pump(const Duration(milliseconds: 100));
    });

    testWidgets('closing the page while in full screen brings it upright', (
      t,
    ) async {
      final calls = recordPlatform(t);
      await _open(t, _FakeCameras(), locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);
      await t.tap(find.byTooltip('Full screen'));
      await _frames(t, 2);

      // the page goes away while still forced to landscape
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(
        orientations(calls).last,
        contains('DeviceOrientation.portraitUp'),
      );
      // and nothing frees it afterwards
      await t.pump(const Duration(seconds: 2));
      expect(
        orientations(calls).last,
        contains('DeviceOrientation.portraitUp'),
      );
      expect(orientations(calls), isNot(contains('[]')));
    });

    testWidgets('the back arrow leaves full screen first, not the page', (
      t,
    ) async {
      recordPlatform(t);
      await _open(t, _FakeCameras(), locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);
      await t.tap(find.byTooltip('Full screen'));
      await _frames(t, 2);

      await t.tap(find.byTooltip('Back'));
      await t.pump(const Duration(milliseconds: 700));
      expect(find.byType(CameraPlayerScreen), findsOneWidget);
      expect(find.text('Cameras'), findsOneWidget, reason: 'portrait layout');
    });

    testWidgets('a phone simply turned sideways gets the wide layout too', (
      t,
    ) async {
      final calls = recordPlatform(t);
      await _open(
        t,
        _FakeCameras(),
        locale: 'en',
        size: const Size(1600, 800), // 800 x 400 logical, landscape
      );
      await t.tap(find.text('Front door').first);
      await _frames(t);

      expect(t.takeException(), isNull, reason: 'no overflow in landscape');
      expect(find.text('Cameras'), findsNothing, reason: 'no portrait panel');
      expect(find.byKey(const ValueKey('ptz-left')), findsOneWidget);

      // the button now says "exit", and uses it to get upright
      await t.tap(find.byTooltip('Exit full screen'));
      await t.pump();
      expect(
        orientations(calls).last,
        contains('DeviceOrientation.portraitUp'),
      );
      await t.pump(const Duration(milliseconds: 700));
    });
  });

  group('screen sleep and the background', () {
    Future<void> openFront(
      WidgetTester t,
      _FakeCameras repo, {
      List<_FakeController>? controllers,
      _FakeAwake? awake,
    }) async {
      await _open(
        t,
        repo,
        locale: 'en',
        controllers: controllers,
        awake: awake,
      );
      await t.tap(find.text('Front door').first);
      await _frames(t);
    }

    Future<void> goToBackground(WidgetTester t) async {
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
        await t.pump();
      }
    }

    Future<void> comeBack(WidgetTester t) async {
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
        await t.pump();
      }
      await _frames(t);
    }

    testWidgets('the screen is held on while a picture plays, and let go '
        'when it stops', (t) async {
      final awake = _FakeAwake();
      await openFront(t, _FakeCameras(), awake: awake);
      expect(awake.on, isTrue, reason: 'playing keeps the screen awake');

      await t.pump(const Duration(seconds: 4)); // the 3 s test idle limit
      expect(find.text('Paused to save data'), findsOneWidget);
      expect(awake.on, isFalse, reason: 'nobody is watching: let it sleep');

      await t.tap(find.text('Resume'));
      await t.pump();
      expect(awake.on, isTrue);

      await t.tap(find.byTooltip('Back'));
      await _frames(t);
      expect(awake.on, isFalse, reason: 'leaving the screen releases it');
    });

    testWidgets('a failed stream does not keep the screen on', (t) async {
      final awake = _FakeAwake();
      await _open(
        t,
        _FakeCameras(),
        locale: 'en',
        failPlayer: true,
        awake: awake,
      );
      await t.tap(find.text('Front door').first);
      await _frames(t);
      expect(find.text("Couldn't play the stream"), findsOneWidget);
      expect(awake.on, isFalse);
    });

    testWidgets('going to the background closes the stream; coming back '
        'opens a fresh one', (t) async {
      final repo = _FakeCameras();
      final controllers = <_FakeController>[];
      final awake = _FakeAwake();
      await openFront(t, repo, controllers: controllers, awake: awake);
      expect(controllers, hasLength(1));
      expect(repo.liveRequests, ['FRONT-0001|hd']);

      await goToBackground(t);
      expect(controllers.single.disposedCalled, isTrue);
      expect(awake.on, isFalse, reason: 'a locked phone must be free to sleep');

      await comeBack(t);
      // a new address and a new player, not the one from before the sleep
      expect(repo.liveRequests, ['FRONT-0001|hd', 'FRONT-0001|hd']);
      expect(controllers, hasLength(2));
      expect(controllers.last.played, isTrue);
      expect(awake.on, isTrue);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('a held direction is stopped when the app goes away', (
      t,
    ) async {
      final repo = _FakeCameras();
      await openFront(t, repo);
      final g = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('ptz-left'))),
      );
      await t.pump();
      expect(repo.ptzCalls, ['FRONT-0001 left 1500']);

      await goToBackground(t);
      await t.pump();
      expect(repo.ptzCalls.last, 'FRONT-0001 stop -');

      // it must not keep re-issuing moves while away
      final n = repo.ptzCalls.length;
      await t.pump(const Duration(seconds: 3));
      expect(repo.ptzCalls.length, n);
      await g.up();
      await comeBack(t);
    });

    testWidgets('backgrounding while still connecting does not leave a '
        'stream behind', (t) async {
      final repo = _FakeCameras();
      final controllers = <_FakeController>[];
      await _open(t, repo, locale: 'en', controllers: controllers);
      await t.tap(find.text('Front door').first);
      await t.pump(); // just opened, still starting

      await goToBackground(t);
      await _frames(t);
      // whatever was being opened is closed again
      for (final c in controllers) {
        expect(c.disposedCalled, isTrue);
      }
      await comeBack(t);
      expect(find.text('LIVE'), findsOneWidget);
    });
  });

  group('only the grid card is square', () {
    testWidgets('the player keeps its usual rounding', (t) async {
      await _open(t, _FakeCameras(), locale: 'en');
      await t.tap(find.text('Front door').first);
      await _frames(t);

      // the panel under the picture, and the picture thumbnails in the strip
      bool rounded(double top) => t
          .widgetList<ClipRRect>(find.byType(ClipRRect))
          .any(
            (c) =>
                c.borderRadius ==
                BorderRadius.vertical(top: Radius.circular(top)),
          );
      expect(rounded(24), isTrue, reason: 'panel top corners');
      expect(
        t
            .widgetList<ClipRRect>(find.byType(ClipRRect))
            .any((c) => c.borderRadius == BorderRadius.circular(10)),
        isTrue,
        reason: 'strip thumbnails',
      );
    });
  });
}

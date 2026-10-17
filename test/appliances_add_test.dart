import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:homehq/l10n/l10n.dart';
import 'package:homehq/models/appliance.dart';
import 'package:homehq/models/user.dart';
import 'package:homehq/repositories/appliances_repository.dart';
import 'package:homehq/screens/appliance_add_screen.dart';
import 'package:homehq/screens/appliance_detail_screen.dart';
import 'package:homehq/screens/appliances_screen.dart';
import 'package:homehq/state/appliances_provider.dart';
import 'package:homehq/state/auth_state.dart';
import 'package:homehq/widgets/appliances/air_flow.dart';
import 'package:homehq/widgets/appliances/aircon_hero.dart';
import 'package:homehq/widgets/toast.dart';

const _power = ApplianceCapability(key: 'power', type: 'bool');

/// What the server's `local` driver hands out for an air conditioner.
Appliance _aircon({
  String id = 'AC-00001',
  String name = 'Bedroom aircon',
  bool on = false,
  String mode = 'cool',
  int temperature = 25,
  int fan = 2,
  bool swing = false,
  bool removable = true,
}) => Appliance(
  id: id,
  name: name,
  kind: 'aircon',
  room: 'Bedroom',
  brand: 'Daikin',
  model: 'FTKM25',
  connection: 'demo',
  removable: removable,
  online: true,
  capabilities: const [
    _power,
    ApplianceCapability(
      key: 'temperature',
      type: 'int',
      min: 16,
      max: 30,
      unit: '°C',
      adminOnly: true,
    ),
    ApplianceCapability(
      key: 'mode',
      type: 'enum',
      options: ['auto', 'cool', 'dry', 'fan', 'heat'],
      adminOnly: true,
    ),
    ApplianceCapability(
      key: 'fan_speed',
      type: 'int',
      min: 1,
      max: 5,
      adminOnly: true,
    ),
    ApplianceCapability(key: 'swing', type: 'bool', adminOnly: true),
  ],
  state: {
    'power': on,
    'temperature': temperature,
    'mode': mode,
    'fan_speed': fan,
    'swing': swing,
  },
);

class _Repo extends AppliancesRepository {
  _Repo({this.canAdd = true, List<Appliance>? items})
    : items = items ?? [],
      super(Dio());

  bool canAdd;
  List<Appliance> items;
  ApplianceException? addError;
  ApplianceException? removeError;

  /// What was asked for, in order.
  final List<Map<String, String?>> added = [];
  final List<String> removed = [];

  @override
  Future<AppliancesStatus?> status() async =>
      AppliancesStatus(enabled: true, driver: 'local', canAdd: canAdd);

  @override
  Future<List<Appliance>> list({bool refresh = false}) async => items;

  @override
  Future<Appliance> add({
    required String name,
    required String kind,
    String? room,
    String? brand,
    String? model,
    String connection = 'demo',
  }) async {
    added.add({
      'name': name,
      'kind': kind,
      'room': room,
      'brand': brand,
      'model': model,
      'connection': connection,
    });
    final e = addError;
    if (e != null) throw e;
    final made = Appliance(
      id: 'NEW-${added.length}',
      name: name,
      kind: kind,
      room: room,
      brand: brand,
      model: model,
      connection: connection,
      removable: true,
      online: true,
      capabilities: _aircon().capabilities,
      state: _aircon().state,
    );
    items = [...items, made];
    return made;
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    final e = removeError;
    if (e != null) throw e;
    items = [
      for (final a in items)
        if (a.id != id) a,
    ];
  }

  @override
  Future<List<ApplianceEvent>> events(String id, {int limit = 10}) async =>
      const [];

  @override
  Future<ApplianceCommandResult> command(
    String id,
    String capability,
    Object value,
  ) async {
    final i = items.indexWhere((a) => a.id == id);
    final next = {...items[i].state, capability: value};
    items = [...items]..[i] = items[i].withState(next);
    return ApplianceCommandResult(state: next);
  }
}

class _Auth extends AuthNotifier {
  _Auth(this.role);
  final String role;

  @override
  AuthState build() => AuthState(
    loading: false,
    isAuthenticated: true,
    user: User(id: '1', name: 'Somchai', email: 'a@x.io', role: role),
  );
}

Future<void> _frames(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  WidgetTester t,
  _Repo repo, {
  String role = 'admin',
  String initial = '/appliances',
  String locale = 'en',
}) async {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('page /home')),
      ),
      GoRoute(
        path: '/appliances',
        builder: (_, __) => const AppliancesScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const ApplianceAddScreen()),
          GoRoute(
            path: ':id',
            builder: (_, st) => ApplianceDetailScreen(
              id: st.pathParameters['id']!,
              appliance: st.extra is Appliance ? st.extra as Appliance : null,
            ),
          ),
        ],
      ),
    ],
  );

  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appliancesRepoProvider.overrideWithValue(repo),
        authProvider.overrideWith(() => _Auth(role)),
      ],
      child: MaterialApp.router(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        scaffoldMessengerKey: AppToast.messengerKey,
        routerConfig: router,
      ),
    ),
  );
  await _frames(t);
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text));
  await t.pump();
  await t.tap(find.text(text));
  await _frames(t);
}

Future<void> _tapKey(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty) {
    // A long page builds only what is near the screen: scroll back to it.
    await t.drag(find.byType(ListView).first, const Offset(0, 1500));
    await t.pump();
  }
  await t.tap(f);
  await _frames(t);
}

bool _chipSelected(WidgetTester t, String key) =>
    t.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected;

String _nameField(WidgetTester t) =>
    t.widget<TextField>(find.byKey(const ValueKey('name'))).controller!.text;

void main() {
  group('repository: adding and removing', () {
    Dio dioAnswering(
      int status,
      Object? data, {
      void Function(RequestOptions)? seen,
    }) {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            seen?.call(o);
            final res = Response(
              requestOptions: o,
              statusCode: status,
              data: data,
            );
            status < 400
                ? h.resolve(res)
                : h.reject(
                    DioException(
                      requestOptions: o,
                      type: DioExceptionType.badResponse,
                      response: res,
                    ),
                  );
          },
        ),
      );
      return dio;
    }

    test('add sends what was typed and reads the new appliance', () async {
      late RequestOptions seen;
      final dio = dioAnswering(201, {
        'id': 'U-1',
        'name': 'Bedroom aircon',
        'kind': 'aircon',
        'room': 'Bedroom',
        'brand': 'Daikin',
        'model': 'FTKM25',
        'connection': 'demo',
        'removable': true,
        'online': true,
        'capabilities': [
          {'key': 'power', 'type': 'bool'},
        ],
        'state': {'power': false},
      }, seen: (o) => seen = o);
      final made = await AppliancesRepository(dio).add(
        name: 'Bedroom aircon',
        kind: 'aircon',
        room: 'Bedroom',
        brand: 'Daikin',
      );
      expect(seen.method, 'POST');
      expect(seen.path, '/appliances');
      expect(seen.data, {
        'name': 'Bedroom aircon',
        'kind': 'aircon',
        'room': 'Bedroom',
        'brand': 'Daikin',
        'connection': 'demo',
      }, reason: 'unset fields are left out');
      expect(made.id, 'U-1');
      expect(made.brand, 'Daikin');
      expect(made.removable, isTrue);
      expect(made.connection, 'demo');
    });

    test('remove deletes by id', () async {
      late RequestOptions seen;
      await AppliancesRepository(
        dioAnswering(204, null, seen: (o) => seen = o),
      ).remove('U 1');
      expect(seen.method, 'DELETE');
      expect(seen.path, '/appliances/U%201');
    });

    test('refusals are told apart', () async {
      Future<ApplianceFailure> failure(int s, String code) async {
        try {
          await AppliancesRepository(
            dioAnswering(s, {'error': code}),
          ).add(name: 'x', kind: 'aircon');
        } on ApplianceException catch (e) {
          return e.failure;
        }
        fail('expected a failure');
      }

      expect(await failure(403, 'admin_only'), ApplianceFailure.forbidden);
      expect(await failure(400, 'invalid input'), ApplianceFailure.invalid);
      expect(await failure(422, 'not_supported'), ApplianceFailure.unsupported);
    });

    test('status says whether appliances can be added', () async {
      final st = await AppliancesRepository(
        dioAnswering(200, {
          'enabled': true,
          'driver': 'local',
          'can_add': true,
        }),
      ).status();
      expect(st?.canAdd, isTrue);
      final fixed = await AppliancesRepository(
        dioAnswering(200, {'enabled': true, 'driver': 'fake'}),
      ).status();
      expect(fixed?.canAdd, isFalse, reason: 'an older server has no can_add');
    });
  });

  group('the list offers adding', () {
    testWidgets('an admin sees the add button and the invitation', (t) async {
      await _open(t, _Repo());
      expect(find.text('No appliances found'), findsOneWidget);
      expect(find.text('Add your first appliance'), findsOneWidget);
      expect(find.byTooltip('Add appliance'), findsOneWidget);
    });

    testWidgets('a member sees neither', (t) async {
      await _open(t, _Repo(), role: 'member');
      expect(find.text('Add your first appliance'), findsNothing);
      expect(find.byTooltip('Add appliance'), findsNothing);
    });

    testWidgets('nor does a server with a fixed set', (t) async {
      await _open(t, _Repo(canAdd: false, items: [_aircon()]));
      expect(find.byTooltip('Add appliance'), findsNothing);
    });

    testWidgets('the button opens the wizard', (t) async {
      await _open(t, _Repo(items: [_aircon()]));
      await t.tap(find.byTooltip('Add appliance'));
      await _frames(t);
      expect(find.text('Add an appliance'), findsOneWidget);
      expect(find.text('Step 1 of 3 · What is it?'), findsOneWidget);
    });
  });

  group('the add wizard', () {
    testWidgets('a member cannot use it, even by a link', (t) async {
      await _open(t, _Repo(), role: 'member', initial: '/appliances/new');
      expect(find.text('Only an admin can add appliances'), findsOneWidget);
    });

    testWidgets('offers the air conditioner first and starts on it', (t) async {
      await _open(t, _Repo(), initial: '/appliances/new');
      final aircon = t.getTopLeft(find.byKey(const ValueKey('kind-aircon')));
      final light = t.getTopLeft(find.byKey(const ValueKey('kind-light')));
      expect(aircon.dy, lessThan(light.dy));
      expect(find.text('Air conditioner'), findsOneWidget);
      expect(
        find.text('Wind animation, temperature, mode, fan speed and swing'),
        findsOneWidget,
      );
    });

    testWidgets('does not offer a plain fan', (t) async {
      await _open(t, _Repo(), initial: '/appliances/new');
      expect(find.byKey(const ValueKey('kind-cooler')), findsOneWidget);
      expect(find.byKey(const ValueKey('kind-fan')), findsNothing);
      expect(find.text('Fan'), findsNothing);
    });

    testWidgets('offers an air cooler, with its own makers to pick from', (
      t,
    ) async {
      await _open(t, _Repo(), initial: '/appliances/new');
      expect(find.text('Air cooler'), findsOneWidget);
      expect(
        find.text('Speed, left-right swing, water cooling and modes'),
        findsOneWidget,
      );
      await _tapKey(t, 'kind-cooler');
      await _tapText(t, 'Next');
      expect(_nameField(t), 'Air cooler');
      expect(find.text('Hatari'), findsOneWidget);
      expect(find.text('Daikin'), findsNothing, reason: 'an aircon maker');
    });

    testWidgets('suggests a name from the room, until you write your own', (
      t,
    ) async {
      await _open(t, _Repo(), initial: '/appliances/new');
      await _tapText(t, 'Next');
      expect(_nameField(t), 'Air conditioner');

      await _tapKey(t, 'room-bedroom');
      expect(_nameField(t), 'Bedroom Air conditioner');

      await t.enterText(find.byKey(const ValueKey('name')), 'My cold room');
      await _tapKey(t, 'room-kitchen');
      expect(_chipSelected(t, 'room-kitchen'), isTrue, reason: 'it was tapped');
      expect(_nameField(t), 'My cold room', reason: 'their name is kept');
    });

    testWidgets('will not go on without a name', (t) async {
      await _open(t, _Repo(), initial: '/appliances/new');
      await _tapText(t, 'Next');
      await t.enterText(find.byKey(const ValueKey('name')), '   ');
      await _tapText(t, 'Next');
      expect(find.text('Give it a name'), findsOneWidget);
      expect(find.text('Step 2 of 3 · About it'), findsOneWidget);
    });

    testWidgets('a brand chip fills the brand', (t) async {
      await _open(t, _Repo(), initial: '/appliances/new');
      await _tapText(t, 'Next');
      await _tapText(t, 'Daikin');
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('brand')))
            .controller!
            .text,
        'Daikin',
      );
    });

    testWidgets('says what each connection needs, and only the simulated one '
        'can be made', (t) async {
      final repo = _Repo();
      await _open(t, repo, initial: '/appliances/new');
      await _tapText(t, 'Next');
      await _tapText(t, 'Next');
      expect(find.text('Step 3 of 3 · How it connects'), findsOneWidget);

      FilledButton addButton() => t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add appliance'),
      );
      // Simulated: nothing to prepare, and it can be added.
      expect(find.text('Nothing. The server simulates it.'), findsOneWidget);
      expect(addButton().onPressed, isNotNull);

      await _tapKey(t, 'conn-wifi');
      expect(
        find.text(
          'A 2.4 GHz Wi-Fi network (most air conditioners cannot use 5 GHz)',
        ),
        findsOneWidget,
      );
      expect(
        find.text('A HomeHQ driver for that maker on the server'),
        findsOneWidget,
      );
      expect(find.textContaining("isn't available yet"), findsOneWidget);
      expect(addButton().onPressed, isNull);

      await _tapKey(t, 'conn-ir');
      expect(
        find.textContaining('A Wi-Fi smart IR remote (Tuya'),
        findsOneWidget,
      );
      expect(
        find.textContaining('IR is one-way'),
        findsOneWidget,
        reason: 'the caveat about not reading the real state',
      );
      expect(addButton().onPressed, isNull);

      await _tapKey(t, 'conn-homeassistant');
      expect(find.textContaining('long-lived access token'), findsOneWidget);
      expect(addButton().onPressed, isNull);

      await _tapKey(t, 'conn-demo');
      expect(addButton().onPressed, isNotNull);
      expect(repo.added, isEmpty, reason: 'nothing is sent until Add');
    });

    testWidgets('adds the air conditioner and lands on it', (t) async {
      final repo = _Repo();
      await _open(t, repo, initial: '/appliances/new');

      await _tapText(t, 'Next'); // kind: air conditioner
      await _tapKey(t, 'room-bedroom');
      await t.enterText(find.byKey(const ValueKey('model')), 'FTKM25');
      await _tapText(t, 'Daikin');
      await _tapText(t, 'Next');
      await _tapText(t, 'Add appliance');

      expect(repo.added, [
        {
          'name': 'Bedroom Air conditioner',
          'kind': 'aircon',
          'room': 'Bedroom',
          'brand': 'Daikin',
          'model': 'FTKM25',
          'connection': 'demo',
        },
      ]);
      // On the new appliance's page, with the air conditioner drawn.
      expect(find.byType(AirconHero), findsOneWidget);
      expect(find.text('Bedroom Air conditioner added'), findsOneWidget);
    });

    testWidgets('a refused add stays put and says so', (t) async {
      final repo = _Repo()
        ..addError = const ApplianceException(ApplianceFailure.unavailable);
      await _open(t, repo, initial: '/appliances/new');
      await _tapText(t, 'Next');
      await _tapText(t, 'Next');
      await _tapText(t, 'Add appliance');

      expect(repo.added, hasLength(1));
      expect(find.text("Couldn't add the appliance"), findsOneWidget);
      expect(find.text('Step 3 of 3 · How it connects'), findsOneWidget);
    });

    testWidgets('Back goes a step back, and leaves from the first', (t) async {
      await _open(t, _Repo(items: [_aircon()]), initial: '/appliances');
      await t.tap(find.byTooltip('Add appliance'));
      await _frames(t);
      await _tapText(t, 'Next');
      expect(find.text('Step 2 of 3 · About it'), findsOneWidget);

      await t.tap(find.byIcon(Icons.arrow_back));
      await _frames(t);
      expect(find.text('Step 1 of 3 · What is it?'), findsOneWidget);

      await t.tap(find.byIcon(Icons.arrow_back));
      await _frames(t);
      expect(find.text('Bedroom aircon'), findsOneWidget, reason: 'the list');
    });

    testWidgets('speaks Thai', (t) async {
      await _open(t, _Repo(), initial: '/appliances/new', locale: 'th');
      expect(find.text('เพิ่มเครื่องใช้ไฟฟ้า'), findsOneWidget);
      expect(find.text('แอร์'), findsOneWidget);
      await _tapText(t, 'ถัดไป');
      await _tapText(t, 'ถัดไป');
      expect(find.text('สิ่งที่ต้องมี · จำลอง'), findsOneWidget);
    });
  });

  group('the air conditioner page', () {
    testWidgets('draws the unit and says what it is', (t) async {
      await _open(
        t,
        _Repo(items: [_aircon(on: true)]),
        initial: '/appliances/AC-00001',
      );
      expect(find.byType(AirconHero), findsOneWidget);
      // What it is and how it is set; whether it runs is the status's job.
      // The degrees are on the unit's display and the control, not up here.
      expect(
        find.text('Bedroom · Daikin FTKM25 · Simulated · Cool'),
        findsOneWidget,
      );
      // On is what the button and the drawing say; no pill repeats it.
      expect(find.text('On'), findsNothing);
      expect(find.text('Swing'), findsOneWidget);
    });

    testWidgets('puts what it is set to above how it is doing', (t) async {
      await _open(
        t,
        _Repo(items: [_aircon(on: true)]),
        initial: '/appliances/AC-00001',
      );
      final settings = t.getTopLeft(find.text('Temperature')).dy;
      final status = t.getTopLeft(find.text('Check now')).dy;
      final header = t.getTopLeft(find.text('Bedroom aircon').last).dy;
      expect(header, lessThan(settings));
      expect(settings, lessThan(status));
    });

    testWidgets('the big button switches it, like the switch does', (t) async {
      final repo = _Repo(items: [_aircon()]);
      await _open(t, repo, role: 'member', initial: '/appliances/AC-00001');

      await t.tap(find.byIcon(Icons.power_settings_new_rounded));
      await _frames(t);
      expect(repo.items.single.isOn, isTrue);
      expect(
        t.widget<AirconHero>(find.byType(AirconHero)).on,
        isTrue,
        reason: 'the drawing follows the state',
      );
    });

    testWidgets('an admin can remove one they added, after asking', (t) async {
      final repo = _Repo(items: [_aircon()]);
      await _open(t, repo, initial: '/appliances/AC-00001');

      await t.tap(find.byTooltip('Remove'));
      await _frames(t);
      expect(find.text('Remove Bedroom aircon?'), findsOneWidget);

      await t.tap(find.text('Cancel'));
      await _frames(t);
      expect(repo.removed, isEmpty);

      await t.tap(find.byTooltip('Remove'));
      await _frames(t);
      await t.tap(find.widgetWithText(TextButton, 'Remove'));
      await _frames(t);
      expect(repo.removed, ['AC-00001']);
      expect(find.text('Bedroom aircon removed'), findsOneWidget);
    });

    testWidgets('there is no remove for a member, or for a vendor appliance', (
      t,
    ) async {
      await _open(
        t,
        _Repo(items: [_aircon()]),
        role: 'member',
        initial: '/appliances/AC-00001',
      );
      expect(find.byTooltip('Remove'), findsNothing);
    });

    testWidgets('there is no remove for an appliance the server owns', (
      t,
    ) async {
      await _open(
        t,
        _Repo(items: [_aircon(removable: false)]),
        initial: '/appliances/AC-00001',
      );
      expect(find.byTooltip('Remove'), findsNothing);
    });
  });

  group('the drawn air conditioner', () {
    Future<void> show(
      WidgetTester t, {
      bool on = false,
      String mode = 'cool',
      int fan = 2,
      bool swing = false,
      bool enabled = true,
      bool reduceMotion = false,
      ValueChanged<bool>? onPower,
    }) async {
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: AirconHero(
                  on: on,
                  mode: mode,
                  temperature: 22,
                  fanSpeed: fan,
                  swing: swing,
                  enabled: enabled,
                  onPower: onPower ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('stands still while off: it asks for no frames', (t) async {
      await show(t);
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(find.bySemanticsLabel('Air conditioner off'), findsOneWidget);
    });

    testWidgets('moves while on, and stops again once it is off', (t) async {
      await show(t, on: true);
      await t.pump(const Duration(milliseconds: 300));
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'the air is moving');
      expect(
        find.bySemanticsLabel('Air conditioner on, Cool, 22°C'),
        findsOneWidget,
      );

      await show(t, on: false);
      // The louver closes, the last air settles, then nothing is scheduled.
      await t.pump(const Duration(milliseconds: 900));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('does not move when the system asks for no animation', (
      t,
    ) async {
      await show(t, on: true, reduceMotion: true);
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('draws every mode, speed and swing without a problem', (
      t,
    ) async {
      for (final mode in ['auto', 'cool', 'dry', 'fan', 'heat']) {
        for (final fan in [1, 3, 5]) {
          for (final swing in [false, true]) {
            await show(t, on: true, mode: mode, fan: fan, swing: swing);
            await t.pump(const Duration(milliseconds: 250));
            expect(
              t.takeException(),
              isNull,
              reason: '$mode fan $fan swing $swing',
            );
          }
        }
      }
      // And an unknown mode from a newer server.
      await show(t, on: true, mode: 'turbo');
      await t.pump(const Duration(milliseconds: 250));
      expect(t.takeException(), isNull);
    });

    testWidgets('the power button reports what was asked, and can be locked', (
      t,
    ) async {
      final asked = <bool>[];
      await show(t, on: false, onPower: asked.add);
      await t.tap(find.byIcon(Icons.power_settings_new_rounded));
      await t.pump();
      expect(asked, [true]);

      await show(t, on: true, onPower: asked.add);
      await t.tap(find.byIcon(Icons.power_settings_new_rounded));
      await t.pump();
      expect(asked, [true, false]);

      await show(t, on: true, enabled: false, onPower: asked.add);
      await t.tap(find.byIcon(Icons.power_settings_new_rounded));
      await t.pump();
      expect(asked, [
        true,
        false,
      ], reason: 'locked while a command is in flight');
    });

    testWidgets('the air shader builds and takes what the painter sets', (
      t,
    ) async {
      final program = await t.runAsync(loadAirShader);
      expect(program, isNotNull, reason: 'shaders/aircon_air.frag loads');
      final shader = program!.fragmentShader();
      addTearDown(shader.dispose);
      // The last float the painter sets is there; one more is not.
      shader.setFloat(airShaderUniformCount - 1, 0);
      expect(
        () => shader.setFloat(airShaderUniformCount, 0),
        throwsA(anything),
      );
    });

    testWidgets(
      'draws every mode with the shader, and switches on with a gust',
      (t) async {
        await t.runAsync(loadAirShader);
        for (final mode in ['auto', 'cool', 'dry', 'fan', 'heat', 'turbo']) {
          await show(t, on: false, mode: mode, swing: true);
          await t.pump();
          await show(t, on: true, mode: mode, swing: true, fan: 5);
          for (var i = 0; i < 6; i++) {
            await t.pump(const Duration(milliseconds: 200));
          }
          expect(t.takeException(), isNull, reason: mode);
        }
        // A change of fan speed or swing while it runs carries on smoothly.
        await show(t, on: true, fan: 1);
        await t.pump(const Duration(milliseconds: 200));
        expect(t.takeException(), isNull);
        expect(t.binding.hasScheduledFrame, isTrue);
      },
    );
  });

  group('leaving a screen part-way', () {
    Future<void> keyboard(WidgetTester t, bool up) async {
      if (up) {
        t.view.viewInsets = const FakeViewPadding(bottom: 600);
      } else {
        t.view.resetViewInsets();
      }
      await _frames(t);
    }

    testWidgets('typing, then Next while the keyboard is up', (t) async {
      await _open(t, _Repo(items: [_aircon()]));
      await t.tap(find.byTooltip('Add appliance'));
      await _frames(t);
      await _tapText(t, 'Next');
      await t.tap(find.byKey(const ValueKey('name')));
      await keyboard(t, true);
      await t.enterText(find.byKey(const ValueKey('name')), 'Lounge AC');
      await _tapText(t, 'Next');
      await keyboard(t, false);
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    });

    testWidgets('a refused add, then back out with the keyboard up', (t) async {
      final repo = _Repo(items: [_aircon()])
        ..addError = const ApplianceException(ApplianceFailure.unavailable);
      await _open(t, repo);
      await t.tap(find.byTooltip('Add appliance'));
      await _frames(t);
      await _tapText(t, 'Next');
      await _tapText(t, 'Next');
      await _tapText(t, 'Add appliance');
      await _frames(t);
      expect(repo.added, hasLength(1));

      // A step back, into the name, keyboard up, and out of the wizard.
      await t.tap(find.byIcon(Icons.arrow_back));
      await _frames(t);
      await t.tap(find.byKey(const ValueKey('name')));
      await keyboard(t, true);
      for (var i = 0; i < 2; i++) {
        await t.tap(find.byIcon(Icons.arrow_back));
        await _frames(t);
      }
      await keyboard(t, false);
      await t.pump(const Duration(seconds: 12));
      expect(t.takeException(), isNull);
      expect(find.text('Bedroom aircon'), findsWidgets, reason: 'the list');
    });
  });
}

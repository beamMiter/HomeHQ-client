import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:homehq/l10n/l10n.dart';
import 'package:homehq/models/appliance.dart';
import 'package:homehq/models/user.dart';
import 'package:homehq/repositories/appliances_repository.dart';
import 'package:homehq/screens/appliance_detail_screen.dart';
import 'package:homehq/screens/appliances_screen.dart';
import 'package:homehq/state/appliances_provider.dart';
import 'package:homehq/state/auth_state.dart';
import 'package:homehq/widgets/appliances/air_flow.dart';
import 'package:homehq/widgets/appliances/appliance_status.dart';
import 'package:homehq/widgets/appliances/cooler_hero.dart';
import 'package:homehq/widgets/appliances/heater_hero.dart';
import 'package:homehq/widgets/appliances/light_hero.dart';
import 'package:homehq/widgets/toast.dart';

const _power = ApplianceCapability(key: 'power', type: 'bool');

const _light = Appliance(
  id: 'LIGHT-0001',
  name: 'Living room light',
  kind: 'light',
  room: 'Living room',
  online: true,
  capabilities: [
    _power,
    ApplianceCapability(
      key: 'brightness',
      type: 'int',
      min: 1,
      max: 100,
      unit: '%',
      adminOnly: true,
    ),
  ],
  state: {'power': true, 'brightness': 60},
);
const _plug = Appliance(
  id: 'PLUG-00001',
  name: 'Desk plug',
  kind: 'plug',
  room: 'Study',
  online: true,
  capabilities: [_power],
  state: {'power': false},
);
const _ac = Appliance(
  id: 'AC-00001',
  name: 'Bedroom aircon',
  kind: 'aircon',
  room: 'Bedroom',
  online: true,
  capabilities: [
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
      options: ['auto', 'cool', 'heat'],
      adminOnly: true,
    ),
  ],
  state: {'power': true, 'temperature': 25, 'mode': 'cool'},
);
const _heater = Appliance(
  id: 'HEATER-001',
  name: 'Space heater',
  kind: 'heater',
  room: 'Living room',
  online: true,
  capabilities: [_power],
  state: {'power': false},
);
const _fan = Appliance(
  id: 'FAN-00001',
  name: 'Garage fan',
  kind: 'fan',
  room: 'Garage',
  online: false,
  capabilities: [_power],
  state: {'power': false},
);

const _cooler = Appliance(
  id: 'COOLER-001',
  name: 'Bedroom cooler',
  kind: 'cooler',
  room: 'Bedroom',
  online: true,
  capabilities: [
    _power,
    ApplianceCapability(
      key: 'fan_speed',
      type: 'int',
      min: 1,
      max: 3,
      adminOnly: true,
    ),
    ApplianceCapability(key: 'swing', type: 'bool', adminOnly: true),
    ApplianceCapability(key: 'cooling', type: 'bool', adminOnly: true),
    ApplianceCapability(
      key: 'mode',
      type: 'enum',
      options: ['normal', 'natural', 'sleep'],
      adminOnly: true,
    ),
  ],
  state: {
    'power': true,
    'fan_speed': 2,
    'swing': false,
    'cooling': true,
    'mode': 'normal',
  },
);

/// Appliance repository that records what it was asked and can be steered.
class _FakeAppliances extends AppliancesRepository {
  _FakeAppliances({
    this.enabled = true,
    List<Appliance>? items,
    this.commandError,
    this.eventList = const [],
  }) : items = items ?? [_light, _plug, _ac, _heater, _fan],
       super(Dio());

  bool enabled;
  List<Appliance> items;
  ApplianceException? commandError;
  List<ApplianceEvent> eventList;

  /// While set, asking for the list fails with it.
  ApplianceException? listError;

  /// Whether a command's read-back is confirmed.
  bool confirm = true;

  int listCalls = 0;
  final List<bool> refreshFlags = [];

  /// One entry per command, in order: `id capability=value`.
  final List<String> calls = [];

  /// While set, the next command waits for it.
  Completer<void>? holdCommand;

  @override
  Future<AppliancesStatus?> status() async =>
      AppliancesStatus(enabled: enabled, driver: 'fake');

  @override
  Future<List<Appliance>> list({bool refresh = false}) async {
    listCalls++;
    refreshFlags.add(refresh);
    final e = listError;
    if (e != null) throw e;
    return items;
  }

  @override
  Future<ApplianceCommandResult> command(
    String id,
    String capability,
    Object value,
  ) async {
    calls.add('$id $capability=$value');
    await holdCommand?.future;
    final e = commandError;
    if (e != null) throw e;
    final i = items.indexWhere((a) => a.id == id);
    final next = {...items[i].state, capability: value};
    items = [...items]..[i] = items[i].withState(next);
    return ApplianceCommandResult(state: next, confirmed: confirm);
  }

  @override
  Future<List<ApplianceEvent>> events(String id, {int limit = 10}) async =>
      eventList;
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

Future<void> _frames(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  WidgetTester t,
  _FakeAppliances repo, {
  String locale = 'en',
  String role = 'member',
  String initial = '/appliances',
  DateTime? now,
}) async {
  // Tall enough for a whole air-conditioner page, which draws the unit above
  // the controls and the activity list.
  t.view.physicalSize = const Size(800, 2800);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/appliances',
        builder: (_, __) => const AppliancesScreen(),
        routes: [
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
      overrides: [
        appliancesRepoProvider.overrideWithValue(repo),
        authProvider.overrideWith(() => _Auth(role)),
        if (now != null) appliancesClockProvider.overrideWithValue(() => now),
      ],
      retry: (_, _) => null,
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

/// The power switch on the card that shows [name].
Finder _switchOf(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first,
  matching: find.byType(Switch),
);

Switch _switchWidget(WidgetTester t, String name) =>
    t.widget<Switch>(_switchOf(name));

/// What the status badge on the card that shows [name] says.
String _statusOf(WidgetTester t, String name) {
  final badge = find.descendant(
    of: find
        .ancestor(of: find.text(name), matching: find.byType(InkWell))
        .first,
    matching: find.byType(ApplianceStatusBadge),
  );
  return t
      .widget<Text>(find.descendant(of: badge, matching: find.byType(Text)))
      .data!;
}

/// The number on the overview's tile for [status].
String _countOf(WidgetTester t, String status) =>
    t.widget<Text>(find.byKey(ValueKey('status-$status-count'))).data!;

void main() {
  group('AppliancesRepository failures', () {
    Future<ApplianceFailure> failureFor(int status, String? code) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.reject(
            DioException(
              requestOptions: o,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: o,
                statusCode: status,
                data: code == null ? null : {'error': code},
              ),
            ),
          ),
        ),
      );
      try {
        await AppliancesRepository(dio).command('X-0001', 'power', true);
      } on ApplianceException catch (e) {
        return e.failure;
      }
      fail('expected an ApplianceException');
    }

    test('maps each server answer to a failure', () async {
      expect(
        await failureFor(409, 'appliance_offline'),
        ApplianceFailure.offline,
      );
      expect(await failureFor(403, 'admin_only'), ApplianceFailure.forbidden);
      expect(
        await failureFor(422, 'not_supported'),
        ApplianceFailure.unsupported,
      );
      expect(await failureFor(400, 'invalid input'), ApplianceFailure.invalid);
      expect(
        await failureFor(404, 'appliance_not_found'),
        ApplianceFailure.notFound,
      );
      expect(
        await failureFor(503, 'appliances_disabled'),
        ApplianceFailure.disabled,
      );
      expect(
        await failureFor(503, 'appliances_misconfigured'),
        ApplianceFailure.misconfigured,
      );
      expect(await failureFor(429, 'provider_limit'), ApplianceFailure.limited);
      expect(
        await failureFor(502, 'appliances_unavailable'),
        ApplianceFailure.unavailable,
      );
    });

    test('a route that does not exist means an older server', () async {
      expect(await failureFor(404, null), ApplianceFailure.disabled);
    });
  });

  group('appliance list', () {
    testWidgets('groups by room and says how each one is', (t) async {
      final repo = _FakeAppliances();
      await _open(t, repo);

      for (final text in [
        'Living room',
        'Study',
        'Bedroom',
        'Garage',
        'Living room light',
        'Desk plug',
        'Bedroom aircon',
        'Space heater',
        'Garage fan',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // Each says its status in words, and what it is set to while it runs.
      expect(_statusOf(t, 'Living room light'), 'On');
      expect(_statusOf(t, 'Bedroom aircon'), 'On');
      expect(_statusOf(t, 'Desk plug'), 'Off');
      expect(_statusOf(t, 'Space heater'), 'Off');
      expect(_statusOf(t, 'Garage fan'), 'Offline');
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('25°C · Cool'), findsOneWidget);
      // The offline one has no power switch.
      expect(_switchOf('Garage fan'), findsNothing);
      expect(_switchWidget(t, 'Living room light').value, isTrue);
      expect(_switchWidget(t, 'Desk plug').value, isFalse);
    });

    testWidgets('says when appliances are not set up on the server', (t) async {
      final repo = _FakeAppliances(enabled: false);
      await _open(t, repo);

      expect(find.text("Appliances aren't set up yet"), findsOneWidget);
      expect(repo.listCalls, 0, reason: 'must not ask for a list');
    });

    testWidgets('an empty account has its own message', (t) async {
      await _open(t, _FakeAppliances(items: const []));
      expect(find.text('No appliances found'), findsOneWidget);
    });

    testWidgets('anyone can switch power, and the switch follows at once', (
      t,
    ) async {
      final repo = _FakeAppliances();
      await _open(t, repo, role: 'member');

      await t.tap(_switchOf('Desk plug'));
      await _frames(t);

      expect(repo.calls, ['PLUG-00001 power=true']);
      expect(_switchWidget(t, 'Desk plug').value, isTrue);
      expect(_statusOf(t, 'Desk plug'), 'On');
    });

    testWidgets('a failed command puts the switch back and says so', (t) async {
      final repo = _FakeAppliances(
        commandError: const ApplianceException(ApplianceFailure.unavailable),
      );
      await _open(t, repo);

      await t.tap(_switchOf('Desk plug'));
      await _frames(t);

      expect(repo.calls, hasLength(1));
      expect(_switchWidget(t, 'Desk plug').value, isFalse);
      expect(find.text("Couldn't change Desk plug"), findsOneWidget);
    });

    testWidgets(
      'while a command is in flight the switch cannot be flipped again',
      (t) async {
        final hold = Completer<void>();
        final repo = _FakeAppliances()..holdCommand = hold;
        await _open(t, repo);

        await t.tap(_switchOf('Desk plug'));
        await t.pump();
        expect(_switchWidget(t, 'Desk plug').onChanged, isNull);

        hold.complete();
        await _frames(t);
        expect(_switchWidget(t, 'Desk plug').onChanged, isNotNull);
        expect(repo.calls, hasLength(1));
      },
    );

    testWidgets('an offline appliance opens with what was last known', (
      t,
    ) async {
      final repo = _FakeAppliances();
      await _open(t, repo);

      await t.tap(find.text('Garage fan'));
      await _frames(t);

      expect(
        find.text("Can't be reached right now. Last known: Off."),
        findsOneWidget,
      );
      // No switch claiming a state nobody can vouch for, and nothing sent.
      expect(find.byType(Switch), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('pull-to-refresh asks the server to skip its cache', (t) async {
      final repo = _FakeAppliances();
      await _open(t, repo);
      expect(repo.refreshFlags, [false]);

      await t.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await _frames(t, 12);

      expect(repo.refreshFlags.last, isTrue);
    });
  });

  group('appliance page', () {
    testWidgets('a member sees the other controls, locked', (t) async {
      final repo = _FakeAppliances();
      await _open(t, repo, role: 'member', initial: '/appliances/AC-00001');

      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('25°C'), findsOneWidget);
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Only an admin can change this'), findsOneWidget);
      expect(t.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(
        t
            .widget<ChoiceChip>(find.byKey(const ValueKey('option-mode-heat')))
            .onSelected,
        isNull,
      );
      // Power is still theirs.
      await t.tap(find.byType(Switch));
      await _frames(t);
      expect(repo.calls, ['AC-00001 power=false']);
    });

    testWidgets('an admin can change a setting and a mode', (t) async {
      final repo = _FakeAppliances();
      await _open(t, repo, role: 'admin', initial: '/appliances/AC-00001');

      expect(find.text('Only an admin can change this'), findsNothing);

      await t.drag(find.byType(Slider), const Offset(120, 0));
      await _frames(t);
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single, startsWith('AC-00001 temperature='));
      final sent = int.parse(repo.calls.single.split('=').last);
      expect(sent, inInclusiveRange(16, 30));
      expect(sent, greaterThan(25), reason: 'dragged to the right');

      await t.tap(find.byKey(const ValueKey('option-mode-heat')));
      await _frames(t);
      expect(repo.calls.last, 'AC-00001 mode=heat');
      expect(
        t
            .widget<ChoiceChip>(find.byKey(const ValueKey('option-mode-heat')))
            .selected,
        isTrue,
      );
    });

    testWidgets('a refused setting is undone and explained', (t) async {
      final repo = _FakeAppliances(
        commandError: const ApplianceException(ApplianceFailure.forbidden),
      );
      await _open(t, repo, role: 'admin', initial: '/appliances/AC-00001');

      await t.tap(find.byKey(const ValueKey('option-mode-heat')));
      await _frames(t);

      expect(
        t
            .widget<ChoiceChip>(find.byKey(const ValueKey('option-mode-cool')))
            .selected,
        isTrue,
        reason: 'back to how it was',
      );
      expect(find.text('Only an admin can change this'), findsWidgets);
    });

    testWidgets('lists who did what, and the safety switch-off', (t) async {
      final repo = _FakeAppliances(
        eventList: [
          ApplianceEvent(
            capability: 'power',
            value: false,
            source: 'auto_off',
            at: DateTime(2026, 10, 15, 4, 59),
          ),
          ApplianceEvent(
            capability: 'power',
            value: true,
            source: 'user',
            at: DateTime(2026, 10, 15, 2, 59),
            userName: 'Somchai',
          ),
          ApplianceEvent(
            capability: 'temperature',
            value: 22,
            source: 'user',
            at: DateTime(2026, 10, 15, 2, 58),
          ),
        ],
      );
      await _open(t, repo, initial: '/appliances/AC-00001');

      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('Switched off automatically'), findsOneWidget);
      expect(find.text('Somchai switched it on'), findsOneWidget);
      expect(find.text('Someone set Temperature to 22°C'), findsOneWidget);
    });

    testWidgets('a heater says it switches itself off', (t) async {
      await _open(t, _FakeAppliances(), initial: '/appliances/HEATER-001');
      expect(
        find.text('For safety, this switches itself off after a while.'),
        findsOneWidget,
      );
    });

    testWidgets('speaks Thai', (t) async {
      await _open(
        t,
        _FakeAppliances(),
        locale: 'th',
        initial: '/appliances/AC-00001',
      );
      expect(find.text('อุณหภูมิ'), findsOneWidget);
      expect(find.text('เย็น'), findsWidgets);
      expect(find.text('กิจกรรมล่าสุด'), findsOneWidget);
    });
  });

  group('status', () {
    testWidgets('the summary counts each status and shows only those', (
      t,
    ) async {
      await _open(t, _FakeAppliances());
      expect(_countOf(t, 'on'), '2');
      expect(_countOf(t, 'off'), '2');
      expect(_countOf(t, 'offline'), '1');
      expect(find.bySemanticsLabel('2 on, 2 off, 1 offline'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('status-offline')));
      await _frames(t, 2);
      expect(find.text('Garage fan'), findsOneWidget);
      expect(find.text('Desk plug'), findsNothing);
      expect(find.text('Living room light'), findsNothing);

      // Again: all of them.
      await t.tap(find.byKey(const ValueKey('status-offline')));
      await _frames(t, 2);
      expect(find.text('Desk plug'), findsOneWidget);
    });

    testWidgets('the cards say since when, when it switches off, and what '
        'was last known', (t) async {
      final now = DateTime(2026, 10, 16, 21, 0);
      Appliance withTimes(
        Appliance a, {
        required bool on,
        DateTime? since,
        DateTime? autoOffAt,
      }) => Appliance(
        id: a.id,
        name: a.name,
        kind: a.kind,
        room: a.room,
        online: a.online,
        capabilities: a.capabilities,
        state: {...a.state, 'power': on},
        since: since,
        autoOffAt: autoOffAt,
      );
      await _open(
        t,
        _FakeAppliances(
          items: [
            withTimes(
              _heater,
              on: true,
              since: now.subtract(const Duration(hours: 1)),
              autoOffAt: now.add(const Duration(minutes: 50)),
            ),
            withTimes(
              _plug,
              on: false,
              since: now.subtract(const Duration(hours: 2)),
            ),
            withTimes(_fan, on: true),
          ],
        ),
        now: now,
      );
      expect(find.text('switches off in 50 min'), findsOneWidget);
      expect(find.text('since 19:00'), findsOneWidget);
      expect(find.text('last known: On'), findsOneWidget);
    });

    testWidgets('says when something is offline, and that shows only those', (
      t,
    ) async {
      await _open(t, _FakeAppliances());
      expect(find.text("1 appliance can't be reached"), findsOneWidget);
      await t.tap(find.text("1 appliance can't be reached"));
      await _frames(t, 2);
      expect(find.text('Garage fan'), findsOneWidget);
      expect(find.text('Desk plug'), findsNothing);
      expect(
        find.text("1 appliance can't be reached"),
        findsNothing,
        reason: 'already showing them',
      );

      await t.tap(find.byKey(const ValueKey('status-all')));
      await _frames(t, 2);
      expect(find.text('Desk plug'), findsOneWidget);
      expect(_countOf(t, 'all'), '5');
      expect(find.text('2 of 5 on'), findsOneWidget);
    });

    testWidgets('a status nobody has cannot be picked', (t) async {
      await _open(t, _FakeAppliances(items: [_light, _plug]));
      expect(_countOf(t, 'offline'), '0');
      await t.tap(find.byKey(const ValueKey('status-offline')));
      await _frames(t, 2);
      expect(find.text('Desk plug'), findsOneWidget, reason: 'nothing hidden');
    });

    testWidgets('the list is checked again while open, and shows a change '
        'made elsewhere', (t) async {
      final repo = _FakeAppliances();
      await _open(t, repo);
      expect(repo.listCalls, 1);
      expect(_statusOf(t, 'Living room light'), 'On');

      // Someone switches the light off from another phone.
      repo.items = [
        for (final a in repo.items)
          a.id == _light.id ? a.withState({...a.state, 'power': false}) : a,
      ];
      await t.pump(const Duration(seconds: 10));
      await _frames(t, 2);
      expect(repo.listCalls, 2);
      expect(repo.refreshFlags.last, isFalse, reason: "the server's cache");
      expect(_statusOf(t, 'Living room light'), 'Off');
      expect(_countOf(t, 'on'), '1');
    });

    testWidgets('a failed check keeps the list and says it is not up to date', (
      t,
    ) async {
      final repo = _FakeAppliances();
      await _open(t, repo);
      repo.listError = const ApplianceException(ApplianceFailure.unavailable);
      await t.pump(const Duration(seconds: 10));
      await _frames(t, 2);

      expect(find.text('Living room light'), findsOneWidget);
      expect(find.textContaining("Couldn't check just now"), findsOneWidget);

      // Back again: the note goes.
      repo.listError = null;
      await t.pump(const Duration(seconds: 10));
      await _frames(t, 2);
      expect(find.textContaining("Couldn't check just now"), findsNothing);
    });

    testWidgets('no checks in the background, one at once on return', (
      t,
    ) async {
      final repo = _FakeAppliances();
      await _open(t, repo);
      for (final s in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
      }
      final calls = repo.listCalls;
      await t.pump(const Duration(seconds: 30));
      expect(repo.listCalls, calls, reason: 'nothing while in the background');

      for (final s in const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
      }
      await t.pump();
      expect(repo.listCalls, calls + 1, reason: 'checked on return');
      await t.pump(const Duration(seconds: 10));
      expect(repo.listCalls, calls + 2, reason: 'and every 10 s again');
      expect(t.takeException(), isNull);
    });

    testWidgets('checking stops once the screen is gone', (t) async {
      final repo = _FakeAppliances();
      await _open(t, repo);
      await t.pumpWidget(const SizedBox());
      final calls = repo.listCalls;
      await t.pump(const Duration(seconds: 35));
      expect(repo.listCalls, calls);
    });

    testWidgets('says it is switching until the appliance answers', (t) async {
      final hold = Completer<void>();
      final repo = _FakeAppliances()..holdCommand = hold;
      await _open(t, repo);

      await t.tap(_switchOf('Desk plug'));
      await t.pump();
      expect(_statusOf(t, 'Desk plug'), 'Turning on…');

      // A check landing meanwhile does not put the old state back.
      await t.pump(const Duration(seconds: 10));
      expect(_statusOf(t, 'Desk plug'), 'Turning on…');

      hold.complete();
      await _frames(t);
      expect(_statusOf(t, 'Desk plug'), 'On');
    });

    testWidgets('a command the appliance did not confirm is marked', (t) async {
      final repo = _FakeAppliances()..confirm = false;
      await _open(t, repo, initial: '/appliances/PLUG-00001');
      // The check after the command fails too, so nothing has confirmed it.
      repo.listError = const ApplianceException(ApplianceFailure.unavailable);

      await t.tap(find.byType(Switch));
      await _frames(t);
      expect(find.text('On · Not confirmed'), findsOneWidget);
      expect(
        find.text(
          "The command was sent, but the appliance didn't confirm it. "
          'Check again to be sure.',
        ),
        findsOneWidget,
      );

      // Checked, and it really is on.
      repo.listError = null;
      await t.tap(find.text('Check now'));
      await _frames(t);
      expect(repo.refreshFlags.last, isTrue, reason: 'skips the cache');
      expect(find.text('On · Not confirmed'), findsNothing);
      expect(find.text('On'), findsNothing, reason: 'on is the switch\'s job');
      expect(find.text('Checked just now'), findsOneWidget);
    });

    testWidgets('says since when, and when a heater switches itself off', (
      t,
    ) async {
      final now = DateTime(2026, 10, 16, 21, 0);
      final heater = Appliance(
        id: _heater.id,
        name: _heater.name,
        kind: 'heater',
        room: _heater.room,
        online: true,
        capabilities: _heater.capabilities,
        state: const {'power': true},
        status: ApplianceStatus.on,
        since: now.subtract(const Duration(hours: 1, minutes: 10)),
        autoOffAt: now.add(const Duration(minutes: 50)),
      );
      await _open(
        t,
        _FakeAppliances(items: [heater]),
        initial: '/appliances/HEATER-001',
        now: now,
      );

      expect(find.text('On since 19:50 · 1 h 10 min'), findsOneWidget);
      expect(
        find.text('Switches itself off at 21:50 (in 50 min)'),
        findsOneWidget,
      );
      expect(find.text('Checked just now'), findsOneWidget);
    });

    testWidgets('Thai status words', (t) async {
      await _open(t, _FakeAppliances(), locale: 'th');
      expect(_statusOf(t, 'Living room light'), 'เปิดอยู่');
      expect(_statusOf(t, 'Desk plug'), 'ปิดอยู่');
      expect(_statusOf(t, 'Garage fan'), 'ออฟไลน์');
    });
  });

  group('the drawings on the page', () {
    testWidgets('a light is drawn, and follows the brightness as it is '
        'dragged', (t) async {
      final repo = _FakeAppliances();
      await _open(t, repo, role: 'admin', initial: '/appliances/LIGHT-0001');
      LightHero hero() => t.widget<LightHero>(find.byType(LightHero));
      expect(hero().on, isTrue);
      expect(hero().brightness, 60);

      // Mid-drag, before anything is sent.
      final g = await t.startGesture(t.getCenter(find.byType(Slider)));
      await g.moveBy(const Offset(-150, 0));
      await t.pump();
      expect(hero().brightness, lessThan(60));
      expect(repo.calls, isEmpty);

      await g.up();
      await _frames(t);
      expect(repo.calls.single, startsWith('LIGHT-0001 brightness='));
    });

    testWidgets("an air cooler is drawn, with a cooler's controls", (t) async {
      final repo = _FakeAppliances(items: [_cooler]);
      await _open(t, repo, role: 'admin', initial: '/appliances/COOLER-001');
      final hero = t.widget<CoolerHero>(find.byType(CoolerHero));
      expect(hero.on, isTrue);
      expect(hero.cooling, isTrue);
      expect(hero.speed, 2);
      expect(find.text('Cooling'), findsWidgets);
      // The modes are signs, named for a screen reader; the one it is in is
      // written beside the label.
      expect(find.byKey(const ValueKey('option-mode-natural')), findsOneWidget);
      expect(find.bySemanticsLabel('Natural wind'), findsOneWidget);
      expect(find.text('Natural wind'), findsNothing);
      expect(find.text('Normal'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('option-mode-sleep')));
      await _frames(t);
      expect(repo.calls, ['COOLER-001 mode=sleep']);
      expect(t.widget<CoolerHero>(find.byType(CoolerHero)).mode, 'sleep');
    });

    testWidgets('a mode the app has no sign for puts all of them in words', (
      t,
    ) async {
      const odd = Appliance(
        id: 'AC-00009',
        name: 'Odd aircon',
        kind: 'aircon',
        online: true,
        capabilities: [
          _power,
          ApplianceCapability(
            key: 'mode',
            type: 'enum',
            options: ['cool', 'turbo'],
            adminOnly: true,
          ),
        ],
        state: {'power': true, 'mode': 'cool'},
      );
      await _open(
        t,
        _FakeAppliances(items: [odd]),
        role: 'admin',
        initial: '/appliances/AC-00009',
      );
      expect(find.widgetWithText(ChoiceChip, 'Cool'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Turbo'), findsOneWidget);
    });

    testWidgets('a heater is drawn, counting down to its switch-off', (
      t,
    ) async {
      final now = DateTime(2026, 10, 16, 21, 0);
      final heater = Appliance(
        id: _heater.id,
        name: _heater.name,
        kind: 'heater',
        room: _heater.room,
        online: true,
        capabilities: _heater.capabilities,
        state: const {'power': true},
        since: now.subtract(const Duration(minutes: 10)),
        autoOffAt: now.add(const Duration(minutes: 110)),
      );
      await _open(
        t,
        _FakeAppliances(items: [heater]),
        initial: '/appliances/HEATER-001',
        now: now,
      );
      final hero = t.widget<HeaterHero>(find.byType(HeaterHero));
      expect(hero.on, isTrue);
      expect(hero.autoOffAt, heater.autoOffAt);
      expect(
        find.bySemanticsLabel('Heater on, switches itself off in 1 h 50 min'),
        findsOneWidget,
      );
    });

    testWidgets('an air cooler in Thai', (t) async {
      await _open(
        t,
        _FakeAppliances(items: [_cooler]),
        locale: 'th',
        initial: '/appliances/COOLER-001',
      );
      expect(find.text('ทำความเย็น'), findsWidgets);
      expect(find.bySemanticsLabel('ลมธรรมชาติ'), findsOneWidget);
      expect(find.text('ปกติ'), findsOneWidget);
    });
  });

  group('leaving pages', () {
    for (final withShader in [false, true]) {
      testWidgets('open every kind of page and leave it, then a toast still '
          'shows (shader: $withShader)', (t) async {
        if (withShader) await t.runAsync(loadAirShader);
        final repo = _FakeAppliances(
          items: [_light, _plug, _ac, _heater, _fan, _cooler],
        );
        await _open(t, repo, role: 'admin');
        for (final name in [
          'Bedroom aircon',
          'Living room light',
          'Bedroom cooler',
          'Space heater',
          'Desk plug',
          'Garage fan',
        ]) {
          await t.ensureVisible(find.text(name));
          await t.tap(find.text(name));
          await _frames(t, 10);
          expect(t.takeException(), isNull, reason: 'opening $name');
          await t.tap(find.byIcon(Icons.arrow_back));
          await _frames(t, 10);
          expect(t.takeException(), isNull, reason: 'leaving $name');
        }
        AppToast.success('still works');
        await _frames(t, 3);
        expect(t.takeException(), isNull);
        expect(find.text('still works'), findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  });
}

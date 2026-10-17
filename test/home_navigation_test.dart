import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:homehq/l10n/l10n.dart';
import 'package:homehq/models/appliance.dart';
import 'package:homehq/models/home_camera.dart';
import 'package:homehq/models/spending.dart';
import 'package:homehq/models/user.dart';
import 'package:homehq/models/weather.dart';
import 'package:homehq/repositories/appliances_repository.dart';
import 'package:homehq/repositories/cameras_repository.dart';
import 'package:homehq/repositories/dashboard_repository.dart';
import 'package:homehq/router.dart';
import 'package:homehq/state/appliances_provider.dart';
import 'package:homehq/state/auth_state.dart';
import 'package:homehq/state/cameras_provider.dart';
import 'package:homehq/state/dashboard_provider.dart';
import 'package:homehq/state/locale_provider.dart';
import 'package:homehq/state/weather_provider.dart';
import 'package:homehq/widgets/toast.dart';

class _Cameras extends CamerasRepository {
  _Cameras() : super(Dio());

  @override
  Future<List<HomeCamera>> list({bool refresh = false}) async => const [];
}

class _Dashboard extends DashboardRepository {
  _Dashboard() : super(Dio());

  @override
  Future<Spending> spending({String? month}) async => Spending.fromJson({
    'month': '2026-10',
    'currency': 'THB',
    'total_spent': 1234,
    'bills': {'paid': 1000},
    'purchases': {'spent': 234},
  });
}

class _Appliances extends AppliancesRepository {
  _Appliances() : super(Dio());

  static const _power = ApplianceCapability(key: 'power', type: 'bool');
  static const _ac = Appliance(
    id: 'AC-00001',
    name: 'Bedroom aircon',
    kind: 'aircon',
    room: 'Bedroom',
    online: true,
    capabilities: [_power],
    state: {'power': true},
  );

  @override
  Future<AppliancesStatus?> status() async =>
      const AppliancesStatus(enabled: true);

  static const _fan = Appliance(
    id: 'FAN-00001',
    name: 'Garage fan',
    kind: 'fan',
    room: 'Garage',
    capabilities: [_power],
    state: {'power': false},
  );

  @override
  Future<List<Appliance>> list({bool refresh = false}) async => const [
    _ac,
    _fan,
  ];

  @override
  Future<List<ApplianceEvent>> events(String id, {int limit = 10}) async =>
      const [];
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    loading: false,
    isAuthenticated: true,
    user: User(id: '1', name: 'Somchai', email: 'a@x.io'),
  );
}

Future<void> _frames(WidgetTester t, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// The real app router, from the real Home screen, with the network faked.
Future<void> _openApp(WidgetTester t) async {
  t.view.physicalSize = const Size(780, 2800);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_Auth.new),
        sharedPreferencesProvider.overrideWithValue(null),
        camerasRepoProvider.overrideWithValue(_Cameras()),
        appliancesRepoProvider.overrideWithValue(_Appliances()),
        dashboardRepoProvider.overrideWithValue(_Dashboard()),
        currentWeatherProvider.overrideWith(
          (ref) async => WeatherNow(
            temperature: 31,
            windSpeed: 3,
            weatherCode: 2,
            time: DateTime(2026, 10, 15, 14),
          ),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          scaffoldMessengerKey: AppToast.messengerKey,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );
  await _frames(t);
}

Future<void> _tapBack(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.arrow_back));
  await _frames(t);
}

void main() {
  testWidgets('Home -> Appliances -> appliance, and back all the way', (
    t,
  ) async {
    await _openApp(t);
    expect(find.text('Medicine Stock'), findsOneWidget, reason: 'on Home');

    await t.tap(find.text('Home Appliances'));
    await _frames(t);
    expect(find.text('Bedroom aircon'), findsOneWidget, reason: 'the list');
    expect(find.text('Medicine Stock'), findsNothing);

    await t.tap(find.text('Bedroom aircon'));
    await _frames(t);
    expect(find.text('Recent activity'), findsOneWidget, reason: 'the page');

    await _tapBack(t);
    expect(find.text('Recent activity'), findsNothing);
    expect(find.text('Bedroom aircon'), findsOneWidget, reason: 'the list');

    await _tapBack(t);
    expect(find.text('Medicine Stock'), findsOneWidget, reason: 'back on Home');
  });

  testWidgets('the appliances tile on Home says how many are on', (
    t,
  ) async {
    await _openApp(t);
    expect(find.text('1 of 2 on · 1 offline'), findsOneWidget);
  });

  testWidgets(
    'the Spending Dashboard tile opens the dashboard, and back is Home',
    (t) async {
      await _openApp(t);

      await t.tap(find.text('Spending Dashboard'));
      await _frames(t);
      // The route exists in the app's own router (a typo or a missing route
      // would show "no routes for location" instead).
      expect(find.textContaining('no routes for location'), findsNothing);
      expect(find.byKey(const ValueKey('hero')), findsOneWidget);
      expect(find.text('฿1,234'), findsOneWidget);

      await _tapBack(t);
      expect(
        find.text('Medicine Stock'),
        findsOneWidget,
        reason: 'back on Home',
      );
    },
  );

  testWidgets('the account button on Home opens the account page', (t) async {
    await _openApp(t);

    await t.tap(find.byTooltip(l10nFor(const Locale('en')).accountOpen));
    await _frames(t);

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Medicine Stock'), findsNothing, reason: 'left Home');

    await _tapBack(t);
    expect(find.text('Medicine Stock'), findsOneWidget, reason: 'back on Home');
  });

  testWidgets('the list opened with nothing below it goes back to Home', (
    t,
  ) async {
    await _openApp(t);
    GoRouter.of(t.element(find.byType(Scaffold).first)).go('/appliances');
    await _frames(t);
    expect(find.text('Bedroom aircon'), findsOneWidget);
    expect(find.text('Medicine Stock'), findsNothing);

    await _tapBack(t);
    expect(find.text('Medicine Stock'), findsOneWidget, reason: 'back on Home');
  });

  testWidgets('a link straight to an appliance still has a way back to Home', (
    t,
  ) async {
    await _openApp(t);
    GoRouter.of(
      t.element(find.byType(Scaffold).first),
    ).go('/appliances/AC-00001');
    await _frames(t);
    expect(find.text('Recent activity'), findsOneWidget);

    await _tapBack(t);
    expect(find.text('Recent activity'), findsNothing);
    expect(find.text('Bedroom aircon'), findsOneWidget, reason: 'the list');

    await _tapBack(t);
    expect(find.text('Medicine Stock'), findsOneWidget, reason: 'back on Home');
  });
}

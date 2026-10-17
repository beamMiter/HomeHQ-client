import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'total_spent': 0,
  });
}

class _Appliances extends AppliancesRepository {
  _Appliances() : super(Dio());
  final items = <Appliance>[];

  @override
  Future<AppliancesStatus?> status() async =>
      const AppliancesStatus(enabled: true, driver: 'local', canAdd: true);

  @override
  Future<List<Appliance>> list({bool refresh = false}) async => [...items];

  @override
  Future<Appliance> add({
    required String name,
    required String kind,
    String? room,
    String? brand,
    String? model,
    String connection = 'demo',
  }) async {
    final a = Appliance.fromJson({
      'id': '2b077655-973c-477a-bf64-7e5c19311a56',
      'name': name,
      'kind': 'cooler',
      'room': room,
      'brand': brand,
      'connection': 'demo',
      'removable': true,
      'online': true,
      'status': 'off',
      'checked_at': '2026-10-16T14:43:11.814059+07:00',
      'capabilities': [
        {'key': 'power', 'type': 'bool'},
        {
          'key': 'fan_speed',
          'type': 'int',
          'min': 1,
          'max': 3,
          'admin_only': true,
        },
        {'key': 'swing', 'type': 'bool', 'admin_only': true},
        {'key': 'cooling', 'type': 'bool', 'admin_only': true},
        {
          'key': 'mode',
          'type': 'enum',
          'options': ['normal', 'natural', 'sleep'],
          'admin_only': true,
        },
      ],
      'state': {
        'cooling': false,
        'fan_speed': 2,
        'mode': 'normal',
        'power': false,
        'swing': false,
      },
    });
    items.add(a);
    return a;
  }

  @override
  Future<List<ApplianceEvent>> events(String id, {int limit = 10}) async =>
      const [];
}

class _Admin extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    loading: false,
    isAuthenticated: true,
    user: User(id: '1', name: 'Somchai', email: 'a@x.io', role: 'admin'),
  );
}

Future<void> _frames(WidgetTester t, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Adding an appliance through the app's own router, from Home to the new
/// appliance's page, then letting the toast, the status checks and the drawing
/// run on: nothing may go wrong after the wizard hands over to the new page.
void main() {
  testWidgets(
    'add an air cooler from Home, with the real router',
    (t) async {
      t.view.physicalSize = const Size(780, 2800);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final errors = <Object>[];
      final repo = _Appliances();
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWith(_Admin.new),
            sharedPreferencesProvider.overrideWithValue(null),
            camerasRepoProvider.overrideWithValue(_Cameras()),
            appliancesRepoProvider.overrideWithValue(repo),
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

      await t.tap(find.text('Home Appliances'));
      await _frames(t);
      await t.tap(find.byTooltip('Add appliance'));
      await _frames(t);
      await t.tap(find.byKey(const ValueKey('kind-cooler')));
      await _frames(t, 3);
      await t.tap(find.text('Next'));
      await _frames(t, 3);
      await t.tap(find.text('Bathroom'));
      await _frames(t, 3);
      await t.tap(find.text('Hatari'));
      await _frames(t, 3);
      await t.tap(find.text('Next'));
      await _frames(t, 3);
      await t.tap(find.text('Add appliance'));
      await _frames(t, 20);
      // Let the toast, the checks and the drawing run on.
      for (var i = 0; i < 15; i++) {
        await t.pump(const Duration(seconds: 1));
        final e = t.takeException();
        if (e != null) errors.add(e);
      }
      expect(find.text('Bathroom Air cooler'), findsWidgets);
      expect(errors, isEmpty);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}

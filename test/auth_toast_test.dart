// Signing in and signing out each show a toast, in the real app (router,
// toast boundary and all). The boundary clears toasts when the signed-in state
// flips, so what matters here is that these two are raised after it and
// survive the redirect.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homehq/main.dart';
import 'package:homehq/models/user.dart';
import 'package:homehq/models/weather.dart';
import 'package:homehq/screens/home_screen.dart';
import 'package:homehq/screens/login_screen.dart';
import 'package:homehq/state/auth_state.dart';
import 'package:homehq/state/weather_provider.dart';

const _user = User(id: 'u1', name: 'A', email: 'a@x.io', role: 'member');

/// Auth that answers like the server would, without a network.
class _FakeAuth extends AuthNotifier {
  _FakeAuth({this.accept = true});
  final bool accept;

  @override
  AuthState build() => const AuthState(loading: false);

  @override
  Future<bool> login(String email, String password) async {
    if (!accept) {
      state = state.copyWith(loading: false, error: 'Invalid credentials');
      return false;
    }
    state = state.copyWith(user: _user, isAuthenticated: true, loading: false);
    return true;
  }

  @override
  Future<void> logout() async {
    state = const AuthState(loading: false);
  }
}

Future<void> _pump(WidgetTester t, {bool accept = true}) async {
  dotenv.loadFromString(envString: 'API_BASE_URL=http://127.0.0.1:8080/api/v1');
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => _FakeAuth(accept: accept)),
        currentWeatherProvider.overrideWith(
          (ref) async => WeatherNow(
            temperature: 31,
            windSpeed: 5,
            weatherCode: 0,
            time: DateTime(2026, 1, 1),
          ),
        ),
      ],
      child: const HomeHqApp(),
    ),
  );
  await t.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
}

Future<void> _signIn(WidgetTester t) async {
  final fields = find.byType(TextFormField);
  await t.enterText(fields.at(0), 'a@x.io');
  await t.enterText(fields.at(1), 'secret123');
  await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

/// Signing out is on the Account page, opened from the avatar on Home.
Future<void> _signOut(WidgetTester t) async {
  await t.tap(find.byTooltip('Open your account'));
  await t.pumpAndSettle();
  await t.scrollUntilVisible(
    find.text('Sign out'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Sign out'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('signing in shows a success toast on the home screen', (t) async {
    await _pump(t);
    await _signIn(t);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
  });

  testWidgets('signing out shows a toast on the login screen', (t) async {
    await _pump(t);
    await _signIn(t);
    expect(find.byType(HomeScreen), findsOneWidget);

    // Let the sign-in toast go, so only the sign-out one can be found.
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Signed in'), findsNothing);

    await _signOut(t);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Signed out'), findsOneWidget);
    expect(find.text('Signed in'), findsNothing);
  });

  testWidgets('a toast raised on the home screen is not left over after '
      'signing out', (t) async {
    await _pump(t);
    await _signIn(t);

    // The "coming soon" toast from the notifications button.
    await t.tap(find.byTooltip('Notifications'));
    await t.pump();
    // The sign-in toast leaves first, then this one takes its place.
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('soon'), findsOneWidget);

    await _signOut(t);

    expect(find.textContaining('soon'), findsNothing);
    expect(find.text('Signed out'), findsOneWidget);
  });

  testWidgets('a failed sign-in shows no success toast', (t) async {
    await _pump(t, accept: false);
    await _signIn(t);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Signed in'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}

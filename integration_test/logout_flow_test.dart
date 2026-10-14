// End-to-end: runs the real app against the local API (admin@example.com from
// `go run ./cmd/seed`). Needs the server up and a booted iOS Simulator or
// Android emulator:
//
//   flutter test integration_test/logout_flow_test.dart -d <device-id>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:homehq/main.dart' as app;
import 'package:homehq/state/location_controller.dart';
import 'package:homehq/state/weather_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pump in small steps. pumpAndSettle would never return here because of
  /// looping progress indicators.
  Future<bool> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
    for (var i = 0; i < seconds * 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (f.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> wait(WidgetTester t, double seconds) async {
    for (var i = 0; i < (seconds * 10).round(); i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  /// What is visible on screen right now that is not ordinary page content.
  void snapshot(String label) {
    final texts = <String>[];
    for (final e in find.byType(Text).evaluate()) {
      final w = e.widget as Text;
      final s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
      if (s.isNotEmpty && !texts.contains(s)) texts.add(s);
    }
    final snacks = [
      for (final e in find.byType(SnackBar).evaluate())
        ((e.widget as SnackBar).content is Text
                ? ((e.widget as SnackBar).content as Text).data
                : '(non-text)') ??
            '',
    ];
    // ignore: avoid_print
    print(
      '\n##### [$label]\n'
      '  snackbars : $snacks\n'
      '  dialogs   : ${find.byType(AlertDialog).evaluate().length}\n'
      '  texts     : ${texts.take(40).join(' | ')}',
    );
  }

  Future<void> login(WidgetTester t, String email, String pw) async {
    final fields = find.byType(TextFormField);
    expect(await waitFor(t, fields), isTrue, reason: 'login form never showed');
    await t.enterText(fields.at(0), email);
    await t.enterText(fields.at(1), pw);
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
  }

  testWidgets('login -> bell snackbar -> logout -> login screen -> login again', (
    t,
  ) async {
    app.main();

    // 1) Cold start. A session persisted in secure storage survives app
    //    re-installs on the simulator, so we may land on Home or on Login.
    final logout = find.byTooltip('Logout');
    final loginForm = find.byType(TextFormField);
    for (
      var i = 0;
      i < 300 && loginForm.evaluate().isEmpty && logout.evaluate().isEmpty;
      i++
    ) {
      await t.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print(
      '\n##### cold start landed on: '
      '${logout.evaluate().isNotEmpty ? 'HOME (session restored)' : 'LOGIN'}',
    );
    if (loginForm.evaluate().isNotEmpty) {
      await login(t, 'admin@example.com', 'admin2026');
    }
    expect(await waitFor(t, logout), isTrue, reason: 'never reached home');
    await wait(t, 3);
    snapshot('A. home right after start/login');

    // Does the weather card ever resolve, and if not, which stage is stuck?
    final scope = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp).first),
    );
    String dump() {
      final loc = scope.read(locationControllerProvider);
      final w = scope.read(currentWeatherProvider);
      return 'location: lat=${loc.location?.lat} lng=${loc.location?.lng} '
          'src=${loc.location?.source} issue=${loc.issue} '
          'resolving=${loc.resolving} | weather: '
          '${w.isLoading
              ? 'LOADING'
              : w.hasError
              ? 'ERROR ${w.error}'
              : 'DATA ${w.value?.temperature}C'}';
    }

    // ignore: avoid_print
    print('\n##### providers @ +3s : ${dump()}');
    await wait(t, 12);
    // ignore: avoid_print
    print('##### providers @ +15s: ${dump()}');

    // 2) something the user might plausibly have done on home just before logging out
    await t.tap(find.byTooltip('Notifications'));
    await wait(t, 0.5);
    snapshot('B. home, after tapping the bell (SnackBar expected)');

    // 3) log out straight away
    await t.tap(logout);
    final form = find.byType(TextFormField);
    expect(await waitFor(t, form), isTrue, reason: 'never reached login');
    await wait(t, 0.6);
    snapshot('C. login screen right after logout');
    // Regression: a toast raised on Home used to survive the redirect and pop
    // up on the login screen.
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'a toast from the previous session leaked onto the login screen',
    );
    expect(find.text('Coming soon: Notifications'), findsNothing);

    // 4) log back in
    await login(t, 'admin@example.com', 'admin2026');
    expect(await waitFor(t, find.byTooltip('Logout')), isTrue);
    await wait(t, 3);
    snapshot('D. home after logging in again');
  });
}

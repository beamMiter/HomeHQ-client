// End-to-end: the real app adds an air cooler (sign in, Home, Home
// Appliances, the add wizard with the keyboard up, the new appliance's page,
// back to the list). It ADDS an appliance, so it only runs against a
// throwaway API given at build time, never the one in the .env:
//
//   flutter test integration_test/appliance_add_flow_test.dart -d <device> \
//     --dart-define=API_BASE_URL=http://127.0.0.1:18082/api/v1
//
// (the server seeded with admin@example.com / admin2026, APPLIANCES_DRIVER=local)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:homehq/l10n/l10n.dart';
import 'package:homehq/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  void say(String s) {
    // ignore: avoid_print
    print('##### $s');
  }

  const api = String.fromEnvironment('API_BASE_URL');

  testWidgets('add an air cooler on the real app', skip: api.isEmpty, (
    t,
  ) async {
    app.main();
    final form = find.byType(TextFormField);
    final appliancesTile = find.text('Home Appliances');
    for (
      var i = 0;
      i < 300 && form.evaluate().isEmpty && appliancesTile.evaluate().isEmpty;
      i++
    ) {
      await t.pump(const Duration(milliseconds: 100));
    }
    if (form.evaluate().isNotEmpty) {
      say('login');
      await t.enterText(form.at(0), 'admin@example.com');
      await t.enterText(form.at(1), 'admin2026');
      await t.tap(find.byType(FilledButton).first);
    }
    expect(
      await waitFor(t, appliancesTile),
      isTrue,
      reason: 'never reached home',
    );
    await wait(t, 2);
    AppLocalizations l10n() =>
        AppLocalizations.of(t.element(find.byType(Scaffold).last))!;

    say('open appliances');
    await t.tap(appliancesTile);
    await wait(t, 2);

    // Adds one; it must say so and land on its page.
    Future<String> add(String kind, String room, {bool type = false}) async {
      await t.tap(find.byTooltip(l10n().applAddButton));
      await wait(t, 1.5);
      await t.ensureVisible(find.byKey(ValueKey('kind-$kind')));
      await t.tap(find.byKey(ValueKey('kind-$kind')));
      await wait(t, 0.5);
      await t.tap(find.text(l10n().applNext));
      await wait(t, 1);
      await t.tap(find.byKey(ValueKey('room-$room')));
      await wait(t, 0.5);
      final nameField = find.byKey(const ValueKey('name'));
      if (type) {
        await t.ensureVisible(nameField);
        await t.tap(nameField);
        await wait(t, 0.5);
        await t.enterText(nameField, 'Typed $kind');
        await wait(t, 0.5);
      }
      final name = t.widget<TextField>(nameField).controller!.text;
      await t.tap(find.text(l10n().applNext));
      await wait(t, 1);
      say('add $name');
      await t.tap(find.text(l10n().applAddButton).last);
      final toast = find.text(l10n().applAddedToast(name));
      expect(
        await waitFor(t, toast, seconds: 8),
        isTrue,
        reason: 'no "added" toast for $name',
      );
      // Landed on its page: its name in the bar, and the status card.
      expect(
        await waitFor(t, find.text(l10n().applCheckNow), seconds: 5),
        isTrue,
        reason: 'did not land on $name',
      );
      await wait(t, 3);
      say('added $name, toast and page OK');
      await t.tap(find.byIcon(Icons.arrow_back));
      await wait(t, 2);
      return name;
    }

    final names = [
      await add('cooler', 'bathroom'),
      await add('light', 'kitchen', type: true),
      await add('aircon', 'bedroom'),
    ];

    // Into each page, switch it on with the big button, wait, and out.
    for (final name in names) {
      await t.ensureVisible(find.text(name).first);
      await t.tap(find.text(name).first);
      await wait(t, 2);
      await t.tap(find.byIcon(Icons.power_settings_new_rounded).first);
      await wait(t, 4);
      say('$name switched on');
      await t.tap(find.byIcon(Icons.arrow_back));
      await wait(t, 2);
    }

    // And one more add after all that.
    await add('heater', 'living');
    say('done');
  });
}

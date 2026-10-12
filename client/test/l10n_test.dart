import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:homeservice/l10n/l10n.dart';
import 'package:homeservice/state/locale_provider.dart';
import 'package:homeservice/utils/geo.dart';
import 'package:homeservice/widgets/language_sheet.dart';

import 'support/list_fakes.dart';

// The Thai block minus the baht sign (฿, U+0E3F), which is a currency symbol.
final _thai = RegExp(r'[\u0E00-\u0E3E\u0E40-\u0E7F]');

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Iterable<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@'));

/// A tiny app that shows one translated string and a button to pick a language.
class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Text(context.l10n.homeToolsTitle),
              Text(context.l10n.toolBillsCaption),
              TextButton(
                onPressed: () => showLanguageSheet(context),
                child: const Text('open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('translations', () {
    test('Thai and English have exactly the same keys', () {
      final en = _messageKeys(_arb('en')).toSet();
      final th = _messageKeys(_arb('th')).toSet();
      expect(th.difference(en), isEmpty, reason: 'only in Thai');
      expect(en.difference(th), isEmpty, reason: 'missing a Thai translation');
    });

    test('no translation is empty and placeholders match', () {
      final en = _arb('en'), th = _arb('th');
      for (final k in _messageKeys(en)) {
        expect((en[k] as String).trim(), isNotEmpty, reason: 'en $k');
        expect((th[k] as String).trim(), isNotEmpty, reason: 'th $k');

        final meta = en['@$k'] as Map<String, dynamic>?;
        final placeholders =
            (meta?['placeholders'] as Map<String, dynamic>?)?.keys ?? const [];
        for (final p in placeholders) {
          expect(en[k], contains('{$p'), reason: 'en $k uses {$p}');
          expect(th[k], contains('{$p'), reason: 'th $k uses {$p}');
        }
      }
    });

    test('English text has no Thai in it (apart from the language name)', () {
      final en = _arb('en');
      final leaks = [
        for (final k in _messageKeys(en))
          if (_thai.hasMatch(en[k] as String) && k != 'languageThai') k,
      ];
      expect(leaks, isEmpty);
    });
  });

  group('picking the language', () {
    test('device languages we ship are used, others fall back to Thai', () {
      expect(resolveAppLocale(const [Locale('en', 'US')]), const Locale('en'));
      expect(resolveAppLocale(const [Locale('th', 'TH')]), const Locale('th'));
      // first supported one wins, in the device's order of preference
      expect(
        resolveAppLocale(const [Locale('fr'), Locale('en'), Locale('th')]),
        const Locale('en'),
      );
      expect(resolveAppLocale(const [Locale('ja')]), const Locale('th'));
      expect(resolveAppLocale(const []), const Locale('th'));
      expect(resolveAppLocale(null), const Locale('th'));
    });

    test('code without a BuildContext follows the chosen language', () {
      expect(l10nFor(const Locale('en')).commonSave, 'Save');
      expect(l10nFor(const Locale('th')).commonSave, 'บันทึก');
    });
  });

  group('language switch', () {
    Future<ProviderContainer> pump(
      WidgetTester t,
      Map<String, Object> saved,
    ) async {
      SharedPreferences.setMockInitialValues(saved);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(container: container, child: const _Probe()),
      );
      await t.pump();
      return container;
    }

    testWidgets('follows the device when nothing is saved', (t) async {
      await pump(t, {});
      // The test device reports en_US.
      expect(find.text('Tools'), findsOneWidget);
    });

    testWidgets('a saved choice is used on start', (t) async {
      await pump(t, {'app_locale': 'th'});
      expect(find.text('เครื่องมือ'), findsOneWidget);
      expect(find.text('Tools'), findsNothing);
    });

    testWidgets('choosing a language changes the text and is remembered', (
      t,
    ) async {
      final container = await pump(t, {'app_locale': 'en'});
      expect(find.text('Tools'), findsOneWidget);

      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('ไทย'));
      await t.pumpAndSettle();

      expect(find.text('เครื่องมือ'), findsOneWidget);
      expect(find.text('Tools'), findsNothing);
      expect(container.read(localeProvider), const Locale('th'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'th');
    });

    testWidgets('"device language" clears the saved choice', (t) async {
      final container = await pump(t, {'app_locale': 'th'});
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('ตามภาษาของเครื่อง'));
      await t.pumpAndSettle();

      expect(container.read(localeProvider), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('app_locale'), isFalse);
    });
  });

  group('wording that depends on a number', () {
    test('plurals', () {
      final en = l10nFor(const Locale('en')), th = l10nFor(const Locale('th'));
      expect(en.billsLateDays(1), '1 day late');
      expect(en.billsLateDays(3), '3 days late');
      expect(th.billsLateDays(3), 'เลยกำหนด 3 วัน');
      expect(en.purchItemsCount(1), '1 item');
      expect(en.purchItemsCount(4), '4 items');
    });

    test('distances use the unit of the language', () {
      final en = l10nFor(const Locale('en')), th = l10nFor(const Locale('th'));
      expect(formatDistance(850, en), '850 m');
      expect(formatDistance(850, th), '850 ม.');
      expect(formatDistance(3420, en), '3.4 km');
      expect(formatDistance(3420, th), '3.4 กม.');
      // no language given: the Thai units (what the plain tests rely on)
      expect(formatDistance(3420), '3.4 กม.');
    });
  });

  // The guard against forgetting a string: every list screen, in English, must
  // have no Thai text on it. (Sample data is English, so any Thai is UI.)
  group('English UI is fully English', () {
    for (final name in listScreens.keys) {
      for (final filled in [true, false]) {
        testWidgets('$name (${filled ? 'with data' : 'empty'})', (t) async {
          final built = listScreens[name]!(filled: filled);
          await t.pumpWidget(
            ProviderScope(
              overrides: built.overrides,
              child: MaterialApp(
                locale: const Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: built.screen,
              ),
            ),
          );
          for (var i = 0; i < 5; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }

          final thaiTexts = [
            for (final e in find.byType(Text).evaluate())
              if (_thai.hasMatch(
                (e.widget as Text).data ??
                    (e.widget as Text).textSpan?.toPlainText() ??
                    '',
              ))
                (e.widget as Text).data ?? '(rich)',
          ];
          expect(thaiTexts, isEmpty, reason: '$name still shows Thai text');

          // Unmount and let Notes' keep-alive timer run out.
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 31));
        });
      }
    }
  });
}

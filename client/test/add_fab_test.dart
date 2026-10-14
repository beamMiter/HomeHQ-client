import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homeservice/l10n/l10n.dart';
import 'package:homeservice/widgets/add_fab.dart';

import 'support/list_fakes.dart';

// What each list screen's button says to a screen reader / on long-press.
const _labels = {
  'Bills': 'New bill',
  'Purchases': 'New purchase',
  'Medicine': 'Add medicine',
  'Notes': 'New note',
};

void main() {
  testWidgets('AddFab is a round button with only a plus', (t) async {
    var taps = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: AddFab(
            color: Colors.indigo,
            tooltip: 'New thing',
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    final fab = t.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.shape, isA<CircleBorder>());
    expect(fab.isExtended, isFalse);
    final size = t.getSize(find.byType(FloatingActionButton));
    expect(size.width, size.height);
    // Only the plus: no words on the button itself.
    expect(find.byType(Text), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await t.tap(find.byType(FloatingActionButton));
    expect(taps, 1);
  });

  for (final name in _labels.keys) {
    testWidgets('$name: the create button is round and named', (t) async {
      final built = listScreens[name]!(filled: true);
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

      final finder = find.byType(AddFab);
      expect(finder, findsOneWidget);
      final fab = t.widget<FloatingActionButton>(
        find.descendant(
          of: finder,
          matching: find.byType(FloatingActionButton),
        ),
      );
      expect(fab.shape, isA<CircleBorder>());
      expect(fab.tooltip, _labels[name]);

      // Unmount and let Notes' keep-alive timer run out.
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 31));
    });
  }
}

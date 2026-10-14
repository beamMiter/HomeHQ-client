import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homeservice/widgets/page_loading.dart';
import 'package:homeservice/widgets/refresh.dart';

import 'support/list_fakes.dart';

Future<void> _frames(WidgetTester tester, [int n = 5]) async {
  // No pumpAndSettle: loaders spin forever and would never settle.
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<BuiltScreen> _open(
  WidgetTester tester,
  String name, {
  bool filled = true,
  bool failing = false,
}) async {
  final built = listScreens[name]!(filled: filled);
  built.setFailing(failing);
  await tester.pumpWidget(
    ProviderScope(
      overrides: built.overrides,
      // Riverpod retries a failed provider by itself after a short delay;
      // switch that off so the fetch counts are exact.
      retry: (_, _) => null,
      child: MaterialApp(home: built.screen),
    ),
  );
  await _frames(tester);
  return built;
}

/// Unmounts the screen and lets Notes' 30 s keep-alive timer run out, so the
/// test doesn't end with a pending timer.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 31));
}

/// Drags down on the scrollable under the [RefreshIndicator] (not the search
/// field's own inner scrollable, which comes first in the tree).
Future<void> _pull(WidgetTester tester) async {
  expect(
    find.byType(RefreshIndicator),
    findsOneWidget,
    reason: 'nothing here reacts to a pull-down',
  );
  final target = find
      .descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.drag(target, const Offset(0, 400));
  await _frames(tester, 10);
}

void main() {
  final button = find.descendant(
    of: find.byType(AppBar),
    matching: find.byTooltip('รีเฟรช'),
  );
  final loadingPage = find.byType(PageLoading);

  for (final name in listScreens.keys) {
    group('$name refresh', () {
      testWidgets('has a refresh button in the app bar', (tester) async {
        await _open(tester, name);
        expect(button, findsOneWidget);
        await _close(tester);
      });

      testWidgets('the button fetches again', (tester) async {
        final built = await _open(tester, name);
        final before = built.calls();
        await tester.tap(button);
        await _frames(tester);
        expect(built.calls(), before + 1);
        await _close(tester);
      });

      testWidgets('the button shows the loading page until it is done', (
        tester,
      ) async {
        final built = await _open(tester, name);
        expect(loadingPage, findsNothing);

        built.hold();
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(loadingPage, findsOneWidget, reason: 'press must be visible');
        // One spinner only: the page loader. None on the button itself.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );

        // Still waiting on the server well past the minimum time.
        await tester.pump(kMinReloadLoader * 3);
        expect(loadingPage, findsOneWidget);

        built.release();
        await _frames(tester);
        expect(loadingPage, findsNothing);
        await _close(tester);
      });

      testWidgets('the loading page shows for a moment even if the server '
          'answers at once', (tester) async {
        await _open(tester, name);

        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(loadingPage, findsOneWidget);

        await tester.pump(kMinReloadLoader * 2);
        expect(loadingPage, findsNothing);
        await _close(tester);
      });

      testWidgets(
        'pull-to-refresh keeps the list instead of the loading page',
        (tester) async {
          final built = await _open(tester, name);
          built.hold();
          await _pull(tester);
          expect(loadingPage, findsNothing);

          built.release();
          await _frames(tester);
          await _close(tester);
        },
      );

      testWidgets('pull-to-refresh works with a short list', (tester) async {
        final built = await _open(tester, name);
        final before = built.calls();
        await _pull(tester);
        expect(built.calls(), before + 1);
        await _close(tester);
      });

      testWidgets('pull-to-refresh works on an empty list', (tester) async {
        final built = await _open(tester, name, filled: false);
        final before = built.calls();
        await _pull(tester);
        expect(built.calls(), before + 1);
        await _close(tester);
      });

      testWidgets('pull-to-refresh works after a failed load', (tester) async {
        final built = await _open(tester, name, failing: true);
        expect(built.calls(), 1);
        built.setFailing(false);
        await _pull(tester);
        expect(built.calls(), 2);
        await _close(tester);
      });
    });
  }
}

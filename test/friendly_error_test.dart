import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homehq/l10n/friendly_error.dart';
import 'package:homehq/l10n/l10n.dart';
import 'package:homehq/services/purchase_api.dart' show AuthRequired;

import 'support/list_fakes.dart';

DioException _status(int code) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: code),
    message:
        'This exception was thrown because the response has a status code of $code',
  );
}

DioException _type(DioExceptionType t) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: t,
);

void main() {
  final en = l10nFor(const Locale('en')), th = l10nFor(const Locale('th'));

  group('friendlyError', () {
    test('says what happened in words, not as an exception', () {
      expect(
        friendlyError(en, _status(500)),
        'The server ran into a problem. Please try again in a moment.',
      );
      expect(friendlyError(en, _status(502)), friendlyError(en, _status(500)));
      expect(
        friendlyError(en, _status(401)),
        'Your session has expired. Please sign in again.',
      );
      expect(
        friendlyError(en, _status(403)),
        "You don't have permission to do this.",
      );
      expect(friendlyError(en, _status(404)), "We couldn't find that.");
      expect(
        friendlyError(en, _type(DioExceptionType.connectionError)),
        "Can't reach the server. Check your connection and try again.",
      );
      expect(
        friendlyError(en, _type(DioExceptionType.receiveTimeout)),
        friendlyError(en, _type(DioExceptionType.connectionError)),
      );
      expect(
        friendlyError(en, AuthRequired()),
        friendlyError(en, _status(401)),
      );
    });

    test('never shows a stack of request details', () {
      for (final e in [
        _status(500),
        _status(418),
        _type(DioExceptionType.unknown),
        Exception('boom'),
        StateError('x'),
        const FormatException('bad'),
      ]) {
        final text = friendlyError(en, e);
        expect(text, isNot(contains('Exception')), reason: '$e');
        expect(text, isNot(contains('RequestOptions')), reason: '$e');
        expect(text, isNot(contains('boom')), reason: '$e');
      }
    });

    test('text that is already worded is kept', () {
      expect(friendlyError(en, 'Camera is busy'), 'Camera is busy');
    });

    test('is translated', () {
      expect(
        friendlyError(th, _status(500)),
        'เซิร์ฟเวอร์มีปัญหา โปรดลองอีกครั้งในอีกสักครู่',
      );
      expect(friendlyError(th, _status(404)), 'ไม่พบข้อมูลที่ต้องการ');
    });
  });

  group('a server error on a list screen', () {
    for (final name in listScreens.keys) {
      testWidgets('$name explains it and offers a retry', (t) async {
        final built = listScreens[name]!(filled: true);
        built.setFailing(true);
        built.setError(_status(500));
        await t.pumpWidget(
          ProviderScope(
            retry: (_, _) => null,
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

        expect(
          find.text(
            'The server ran into a problem. Please try again in a moment.',
          ),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        // Nothing of the request leaks onto the page.
        expect(find.textContaining('DioException'), findsNothing);
        expect(find.textContaining('status code'), findsNothing);

        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 31));
      });
    }
  });

  // "Nothing here yet" and "nothing matches what you typed" are different
  // messages: the first invites adding something, the second a different search.
  group('empty list wording', () {
    Future<void> pump(
      WidgetTester t,
      String name, {
      required bool filled,
    }) async {
      final built = listScreens[name]!(filled: filled);
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
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
    }

    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 31));
    }

    const none = {
      'Bills': 'No bills yet',
      'Purchases': 'No purchases yet',
      'Medicine': 'No medicine yet',
      'Notes': 'No notes yet',
    };
    for (final e in none.entries) {
      testWidgets('${e.key}: no data at all', (t) async {
        await pump(t, e.key, filled: false);
        expect(find.text(e.value), findsOneWidget);
        await close(t);
      });
    }

    const noMatch = {
      'Bills': 'No bills match',
      'Purchases': 'No purchases match',
      'Medicine': 'No medicine matches',
      'Notes': 'No notes match',
    };
    for (final e in noMatch.entries) {
      testWidgets('${e.key}: a search that finds nothing', (t) async {
        // Bills and Medicine search on the server: it answers with nothing.
        // Purchases and Notes filter what they have, so they start filled.
        await pump(t, e.key, filled: !{'Bills', 'Medicine'}.contains(e.key));
        // The list screens each have one search box.
        await t.enterText(find.byType(TextField).first, 'zzzz-nothing');
        await t.pump(const Duration(milliseconds: 700));
        await t.pump(const Duration(milliseconds: 100));
        expect(find.text(e.value), findsOneWidget);
        expect(find.text(none[e.key]!), findsNothing);
        await close(t);
      });
    }
  });
}

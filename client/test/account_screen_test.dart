import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:homeservice/l10n/l10n.dart';
import 'package:homeservice/models/user.dart';
import 'package:homeservice/screens/account_screen.dart';
import 'package:homeservice/services/auth_interceptor.dart';
import 'package:homeservice/services/token_storage.dart';
import 'package:homeservice/state/auth_state.dart';
import 'package:homeservice/widgets/toast.dart';
import 'package:homeservice/widgets/user_avatar.dart';

/// Auth that records what the page asked for and answers as told.
class _Auth extends AuthNotifier {
  _Auth({this.nameOk = true, this.password = PasswordChange.done});
  final bool nameOk;
  final PasswordChange password;

  final names = <String>[];
  final passwords = <(String, String)>[];
  var loggedOut = false;

  @override
  AuthState build() => const AuthState(
    loading: false,
    isAuthenticated: true,
    user: User(
      id: '1',
      name: 'Somchai Jaidee',
      email: 'somchai@example.com',
      role: 'admin',
    ),
  );

  @override
  Future<bool> updateName(String name) async {
    names.add(name);
    if (!nameOk) return false;
    state = state.copyWith(user: state.user!.copyWith(name: name));
    return true;
  }

  @override
  Future<PasswordChange> changePassword(String current, String next) async {
    passwords.add((current, next));
    return password;
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
    state = const AuthState(loading: false);
  }
}

Future<_Auth> _open(WidgetTester t, {_Auth? auth}) async {
  final a = auth ?? _Auth();
  final router = GoRouter(
    initialLocation: '/account',
    routes: [
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(() => a)],
      child: MaterialApp.router(
        scaffoldMessengerKey: AppToast.messengerKey,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
  await t.pumpAndSettle();
  return a;
}

/// Scrolls the page until [target] is on screen.
Future<void> _reveal(WidgetTester t, Finder target) async {
  await t.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.ensureVisible(target);
  await t.pumpAndSettle();
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

/// The text fields of the open bottom sheet, top to bottom.
Finder get _fields => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byType(TextField),
);

Finder get _sheetSave => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.widgetWithText(FilledButton, 'Save'),
);

void main() {
  group('initials', () {
    test('first letters of the first and last words', () {
      expect(initialsOf('Somchai Jaidee'), 'SJ');
      expect(initialsOf('somchai van der jaidee'), 'SJ');
      expect(initialsOf('  Admin  '), 'A');
      expect(initialsOf('สมชาย ใจดี'), 'สใ');
      expect(initialsOf(''), '');
      expect(initialsOf('   '), '');
    });
  });

  group('account page', () {
    testWidgets('shows who is signed in', (t) async {
      await _open(t);
      expect(find.text('SJ'), findsOneWidget);
      expect(find.text('Somchai Jaidee'), findsNWidgets(2)); // header + row
      expect(find.text('somchai@example.com'), findsNWidgets(2));
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('renaming saves, updates the page and says so', (t) async {
      final auth = await _open(t);
      await t.tap(find.text('Name'));
      await t.pumpAndSettle();

      await t.enterText(_fields.first, '  Somsri Jaidee ');
      await t.tap(_sheetSave);
      await _settle(t);

      expect(auth.names, ['Somsri Jaidee']);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Somsri Jaidee'), findsNWidgets(2));
      expect(find.text('Name updated'), findsOneWidget);
    });

    testWidgets('an empty name is not sent', (t) async {
      final auth = await _open(t);
      await t.tap(find.text('Name'));
      await t.pumpAndSettle();
      await t.enterText(_fields.first, '   ');
      await t.tap(_sheetSave);
      await t.pump();

      expect(auth.names, isEmpty);
      expect(find.text('Enter a name'), findsOneWidget);
    });

    testWidgets('a failed rename keeps the sheet open and says so', (t) async {
      await _open(t, auth: _Auth(nameOk: false));
      await t.tap(find.text('Name'));
      await t.pumpAndSettle();
      await t.enterText(_fields.first, 'New Name');
      await t.tap(_sheetSave);
      await _settle(t);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text("Couldn't save. Try again."), findsOneWidget);
    });

    testWidgets('the email cannot be edited', (t) async {
      await _open(t);
      await t.tap(find.text('Email'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

    group('change password', () {
      Future<_Auth> openSheet(WidgetTester t, {_Auth? auth}) async {
        final a = await _open(t, auth: auth);
        await t.tap(find.text('Change password'));
        await t.pumpAndSettle();
        return a;
      }

      Future<void> fill(
        WidgetTester t,
        String cur,
        String next,
        String again,
      ) async {
        await t.enterText(_fields.at(0), cur);
        await t.enterText(_fields.at(1), next);
        await t.enterText(_fields.at(2), again);
        await t.tap(_sheetSave);
        await _settle(t);
      }

      testWidgets('checks the fields before asking the server', (t) async {
        final auth = await openSheet(t);
        await fill(t, '', '123', '456');
        expect(find.text('Enter your current password'), findsOneWidget);
        expect(find.text('At least 6 characters'), findsOneWidget);
        expect(find.text("Passwords don't match"), findsOneWidget);
        expect(auth.passwords, isEmpty);
      });

      testWidgets('success closes the sheet and says so', (t) async {
        final auth = await openSheet(t);
        await fill(t, 'oldpass', 'newpass1', 'newpass1');
        expect(auth.passwords, [('oldpass', 'newpass1')]);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Password changed'), findsOneWidget);
      });

      testWidgets('a wrong current password is shown on that field', (t) async {
        await openSheet(t, auth: _Auth(password: PasswordChange.wrongCurrent));
        await fill(t, 'nope', 'newpass1', 'newpass1');
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Current password is incorrect'), findsOneWidget);
      });

      testWidgets('other failures keep the sheet and say so', (t) async {
        await openSheet(t, auth: _Auth(password: PasswordChange.failed));
        await fill(t, 'oldpass', 'newpass1', 'newpass1');
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text("Couldn't save. Try again."), findsOneWidget);
      });
    });

    testWidgets('language opens the language picker', (t) async {
      await _open(t);
      await _reveal(t, find.text('Language'));
      await t.tap(find.text('Language'));
      await t.pumpAndSettle();
      expect(find.text('ไทย'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('signing out goes to login with a toast', (t) async {
      final auth = await _open(t);
      await _reveal(t, find.text('Sign out'));
      await t.tap(find.text('Sign out'));
      await _settle(t);
      await t.pumpAndSettle();

      expect(auth.loggedOut, isTrue);
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('Signed out'), findsOneWidget);
    });
  });

  group('auth interceptor', () {
    test('a wrong current password does not end the session', () async {
      final storage = _SpyStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = container.read(_refProvider);
      final interceptor = AuthInterceptor(storage: storage, ref: ref);

      final req = RequestOptions(path: '/me/password');
      final handler = _Handler();
      // The error is passed on unchanged (to the screen that asked).
      final passedOn = expectLater(handler.done, throwsA(isA<Object>()));
      interceptor.onError(
        DioException(
          requestOptions: req,
          response: Response(
            requestOptions: req,
            statusCode: 401,
            data: {'error': 'invalid old password'},
          ),
        ),
        handler,
      );
      await passedOn;

      expect(storage.cleared, isFalse);
    });
  });
}

final _refProvider = Provider<Ref>((ref) => ref);

/// Lets the test wait for what the interceptor decided.
class _Handler extends ErrorInterceptorHandler {
  Future<Object?> get done => future;
}

/// Token storage that only records whether it was wiped.
class _SpyStorage extends TokenStorage {
  var cleared = false;

  @override
  Future<String?> getAccessToken() async => 'token';

  @override
  Future<void> clear() async => cleared = true;
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homeservice/models/user.dart';
import 'package:homeservice/shared/app_colors.dart';
import 'package:homeservice/state/auth_state.dart';
import 'package:homeservice/state/toast_boundary.dart';
import 'package:homeservice/widgets/toast.dart';

/// Auth notifier whose state the test drives directly.
class _FakeAuth extends AuthNotifier {
  _FakeAuth(this.initial);
  final AuthState initial;

  @override
  AuthState build() => initial;

  void set(AuthState s) => state = s;
}

/// Two "pages" under one app-level messenger, like the real app.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(toastAuthBoundaryProvider);
    final authed = ref.watch(authProvider).isAuthenticated;
    return MaterialApp(
      scaffoldMessengerKey: AppToast.messengerKey,
      home: Scaffold(body: Center(child: Text(authed ? 'HOME' : 'LOGIN'))),
    );
  }
}

Finder get _snackBar => find.byType(SnackBar);

/// How many pixels in a thin ring just outside [box] are not the plain white
/// page behind it. A drop shadow shows up as exactly these pixels, so this
/// checks what is really painted, not just what the SnackBar was configured
/// with.
Future<int> _pixelsOutside(
  WidgetTester t,
  GlobalKey boundary,
  Rect box, {
  double ring = 14,
}) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = await t.runAsync(() async {
    final image = await render.toImage();
    return (image, await image.toByteData(format: ui.ImageByteFormat.rawRgba));
  });
  final (image, bytes) = data!;
  var painted = 0;
  final outer = box.inflate(ring);
  for (var y = outer.top.floor(); y < outer.bottom.ceil(); y++) {
    for (var x = outer.left.floor(); x < outer.right.ceil(); x++) {
      if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
      // Leave a 1px gap so the container's own edge is never counted.
      if (box.inflate(1).contains(Offset(x + .5, y + .5))) continue;
      final i = (y * image.width + x) * 4;
      final white =
          bytes!.getUint8(i) == 255 &&
          bytes.getUint8(i + 1) == 255 &&
          bytes.getUint8(i + 2) == 255;
      if (!white) painted++;
    }
  }
  return painted;
}

void main() {
  const signedIn = AuthState(
    isAuthenticated: true,
    loading: false,
    user: User(id: 'u1', name: 'A', email: 'a@x.io', role: 'admin'),
  );

  Future<void> pumpApp(WidgetTester t, {AuthState auth = signedIn}) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => _FakeAuth(auth))],
        child: const _TestApp(),
      ),
    );
  }

  group('AppToast', () {
    testWidgets('shows a message with no BuildContext', (t) async {
      await pumpApp(t);

      AppToast.success('บันทึกแล้ว');
      await t.pump();

      expect(find.text('บันทึกแล้ว'), findsOneWidget);
      expect(_snackBar, findsOneWidget);
    });

    testWidgets('latest message replaces the previous one (no queue)', (
      t,
    ) async {
      await pumpApp(t);

      AppToast.info('first');
      AppToast.info('second');
      AppToast.error('third');
      await t.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('third'), findsOneWidget);
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsNothing);
      expect(_snackBar, findsOneWidget);
    });

    testWidgets('disappears by itself after its duration', (t) async {
      await pumpApp(t);

      AppToast.success('ok', duration: const Duration(milliseconds: 800));
      await t.pump(); // inserted
      expect(find.text('ok'), findsOneWidget);

      // The dismiss timer starts when the entrance animation completes, and
      // the fake clock only moves when we pump, so advance it explicitly.
      await t.pump(const Duration(milliseconds: 400)); // entrance done
      expect(find.text('ok'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 900)); // timer fires
      await t.pumpAndSettle(); // exit animation
      expect(find.text('ok'), findsNothing);
    });

    testWidgets('follows the snackbar basics: dark, 4 s, 2 lines', (t) async {
      await pumpApp(t);

      AppToast.success('ok');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final bar = t.widget<SnackBar>(_snackBar);

      // Opaque dark container with light text, no shadow.
      expect(bar.backgroundColor, AppColors.deepNavy);
      expect(bar.elevation, 0);
      // Material: on screen for at least 4 seconds; errors longer.
      expect(bar.duration, const Duration(seconds: 4));
      final text = t.widget<Text>(find.text('ok'));
      expect(text.maxLines, 2);

      AppToast.error('bad');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(
        t.widget<SnackBar>(_snackBar).duration,
        greaterThan(const Duration(seconds: 4)),
      );
    });

    testWidgets('stays above a floating action button', (t) async {
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: AppToast.messengerKey,
          home: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );

      AppToast.success('over the button?');
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));

      final snack = t.getRect(_snackBar);
      final fab = t.getRect(find.byType(FloatingActionButton));
      expect(snack.overlaps(fab), isFalse);
      expect(snack.bottom, lessThanOrEqualTo(fab.top));
    });

    testWidgets('is flat: no drop shadow', (t) async {
      await pumpApp(t);

      for (final show in [AppToast.success, AppToast.error, AppToast.info]) {
        show('flat');
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(t.widget<SnackBar>(_snackBar).elevation, 0);
        AppToast.clear();
        await t.pumpAndSettle(const Duration(milliseconds: 500));
      }
    });

    testWidgets('paints no shadow around the container', (t) async {
      final page = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: page,
          child: MaterialApp(
            scaffoldMessengerKey: AppToast.messengerKey,
            home: const Scaffold(
              backgroundColor: Colors.white,
              body: SizedBox.expand(),
            ),
          ),
        ),
      );

      for (final show in [AppToast.success, AppToast.error, AppToast.info]) {
        show('flat');
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
        final box = t.getRect(
          find.descendant(of: _snackBar, matching: find.byType(Material)).first,
        );
        expect(
          await _pixelsOutside(t, page, box),
          0,
          reason: 'something is painted around the toast',
        );
        AppToast.clear();
        await t.pumpAndSettle(const Duration(milliseconds: 500));
      }
    });

    // Without this, the test above could pass only because it looks at
    // nothing: the same measurement must see the shadow of a stock SnackBar.
    testWidgets('the shadow check can see a shadow', (t) async {
      final page = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: page,
          child: MaterialApp(
            scaffoldMessengerKey: AppToast.messengerKey,
            home: const Scaffold(
              backgroundColor: Colors.white,
              body: SizedBox.expand(),
            ),
          ),
        ),
      );

      AppToast.messengerKey.currentState!.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
          elevation: 6,
          content: Text('raised'),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      final box = t.getRect(
        find.descendant(of: _snackBar, matching: find.byType(Material)).first,
      );
      expect(await _pixelsOutside(t, page, box), greaterThan(0));
    });

    testWidgets('errors get a close button, others do not', (t) async {
      await pumpApp(t);

      AppToast.success('fine');
      await t.pump();
      expect(find.byIcon(Icons.close), findsNothing);

      AppToast.error('broken');
      await t.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('blank messages and calls before the app exists are ignored', (
      t,
    ) async {
      // No app mounted yet: must not throw.
      AppToast.error('too early');

      await pumpApp(t);
      AppToast.info('   ');
      await t.pump();
      expect(_snackBar, findsNothing);
    });

    testWidgets('clear() removes the visible toast', (t) async {
      await pumpApp(t);

      AppToast.info('hello');
      await t.pump();
      expect(find.text('hello'), findsOneWidget);

      AppToast.clear();
      await t.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.text('hello'), findsNothing);
    });
  });

  group('auth boundary', () {
    testWidgets('a toast raised while signed in does not survive logout', (
      t,
    ) async {
      await pumpApp(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      );
      expect(find.text('HOME'), findsOneWidget);

      // The exact bug: a toast from the home screen, then logout.
      AppToast.info('Coming soon: Notifications');
      await t.pump();
      expect(find.text('Coming soon: Notifications'), findsOneWidget);

      (container.read(authProvider.notifier) as _FakeAuth).set(
        const AuthState(loading: false),
      );
      await t.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('Coming soon: Notifications'), findsNothing);
    });

    testWidgets('a toast shown after the flip is not swallowed', (t) async {
      await pumpApp(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      );

      (container.read(authProvider.notifier) as _FakeAuth).set(
        const AuthState(loading: false),
      );
      await t.pump();
      AppToast.error('Invalid email or password');
      await t.pump();

      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('loading flicker during logout does not clear new toasts', (
      t,
    ) async {
      await pumpApp(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      );
      final auth = container.read(authProvider.notifier) as _FakeAuth;

      AppToast.success('Saved');
      await t.pump();

      // Same signed-in value, different loading flag: not a boundary.
      auth.set(signedIn.copyWith(loading: true));
      await t.pump();

      expect(find.text('Saved'), findsOneWidget);
    });
  });
}

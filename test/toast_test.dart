import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homehq/models/user.dart';
import 'package:homehq/shared/app_colors.dart';
import 'package:homehq/state/auth_state.dart';
import 'package:homehq/state/toast_boundary.dart';
import 'package:homehq/widgets/toast.dart';

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

/// The dark rounded container the user sees.
Finder get _card => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == AppColors.deepNavy,
);

/// The edge the toast slides down into and up out of: the bottom of the
/// carrier snack bar, which clips what passes below it.
double _floor(WidgetTester t) => t
    .getRect(
      find.descendant(of: _snackBar, matching: find.byType(Material)).first,
    )
    .bottom;

/// How opaque [text] is (every fade above it multiplied together), or null
/// once it is no longer on screen.
double? _opacity(WidgetTester t, String text) {
  final f = find.text(text);
  if (f.evaluate().isEmpty) return null;
  var v = 1.0;
  for (final e
      in find
          .ancestor(of: f, matching: find.byType(FadeTransition))
          .evaluate()) {
    v *= (e.widget as FadeTransition).opacity.value;
  }
  return v;
}

/// How much of the toast can be seen right now (0 to 1): the share of the card
/// above the floor, times its opacity. Null once it is no longer on screen.
double? _visibility(WidgetTester t, String text) {
  final opacity = _opacity(t, text);
  if (opacity == null) return null;
  final card = t.getRect(_card);
  final shown = ((_floor(t) - card.top) / card.height).clamp(0.0, 1.0);
  return opacity * shown;
}

/// Pumps in [step]s and records how visible [text] is, until it is gone or
/// [limit] has passed. This is what the eye sees as "the way it leaves".
Future<List<double>> _leaving(
  WidgetTester t,
  String text, {
  Duration step = const Duration(milliseconds: 20),
  Duration limit = const Duration(milliseconds: 900),
}) async {
  final seen = <double>[];
  for (var spent = Duration.zero; spent <= limit; spent += step) {
    final v = _visibility(t, text);
    if (v == null) break;
    seen.add(v);
    await t.pump(step);
  }
  return seen;
}

/// The mirror of [_expectSmoothExit] for arriving: never less visible than the
/// frame before, several frames in between, ending fully visible.
void _expectSmoothEntry(List<double> seen, {int minSteps = 6}) {
  expect(seen, isNotEmpty);
  for (var i = 1; i < seen.length; i++) {
    expect(
      seen[i],
      greaterThanOrEqualTo(seen[i - 1] - 1e-9),
      reason: 'it got less visible while arriving: $seen',
    );
  }
  final between = seen.where((v) => v > 0.05 && v < 0.95).length;
  expect(
    between,
    greaterThanOrEqualTo(minSteps),
    reason:
        'it popped in instead of coming in (only $between frames in between): $seen',
  );
  expect(seen.first, lessThan(0.2), reason: 'it did not start hidden: $seen');
  expect(seen.last, greaterThan(0.99), reason: 'it never got fully visible');
}

/// A sequence that leaves smoothly: it never goes back up, and it spends
/// several frames on the way instead of dropping from full to nothing at once.
void _expectSmoothExit(List<double> seen, {int minSteps = 6}) {
  expect(seen, isNotEmpty);
  for (var i = 1; i < seen.length; i++) {
    expect(
      seen[i],
      lessThanOrEqualTo(seen[i - 1] + 1e-9),
      reason: 'it got more visible again: $seen',
    );
  }
  final between = seen.where((v) => v > 0.05 && v < 0.95).length;
  expect(
    between,
    greaterThanOrEqualTo(minSteps),
    reason:
        'it jumped away instead of moving away (only $between frames in between): $seen',
  );
}

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

      // Opaque dark container with light text, no shadow. The container is
      // drawn by the toast itself (so it can fade out), the SnackBar around it
      // is see-through.
      expect(_card, findsOneWidget);
      expect(bar.backgroundColor, Colors.transparent);
      expect(bar.elevation, 0);
      // Material: on screen for at least 4 seconds; errors longer.
      expect(bar.duration, greaterThanOrEqualTo(const Duration(seconds: 4)));
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

  group('AppToast arriving', () {
    testWidgets('it slides up out of the bottom edge over several frames', (
      t,
    ) async {
      await pumpApp(t);
      AppToast.success('hi');
      await t.pump(); // built, still below the edge

      final seen = <double>[];
      for (var i = 0; i < 20; i++) {
        final v = _visibility(t, 'hi');
        if (v != null) {
          seen.add(v);
          expect(
            _opacity(t, 'hi'),
            closeTo(1, 1e-6),
            reason: 'it faded in instead of sliding up',
          );
        }
        await t.pump(const Duration(milliseconds: 20));
      }

      _expectSmoothEntry(seen);
      await t.pumpAndSettle(const Duration(seconds: 8));
    });

    testWidgets(
      'a toast closed while it is still arriving leaves from where it is',
      (t) async {
        await pumpApp(t);
        AppToast.info('quick');
        await t.pump();
        await t.pump(const Duration(milliseconds: 100)); // part-way in

        AppToast.clear();
        await t.pump();
        final seen = await _leaving(t, 'quick');
        for (var i = 1; i < seen.length; i++) {
          expect(
            seen[i],
            lessThanOrEqualTo(seen[i - 1] + 1e-9),
            reason: '$seen',
          );
        }
        await t.pumpAndSettle();
        expect(find.text('quick'), findsNothing);
      },
    );

    testWidgets('with reduce motion on it appears and leaves at once', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: AppToast.messengerKey,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      AppToast.success('still');
      await t.pump();
      await t.pump(const Duration(milliseconds: 1));
      expect(_visibility(t, 'still'), closeTo(1, 1e-6));

      AppToast.clear();
      await t.pump();
      await t.pump(const Duration(milliseconds: 1));
      expect(find.text('still'), findsNothing);
    });
  });

  group('AppToast leaving', () {
    testWidgets('by itself it leaves over several frames, not in one jump', (
      t,
    ) async {
      await pumpApp(t);
      AppToast.success('bye', duration: const Duration(seconds: 1));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400)); // entrance done
      await t.pump(const Duration(milliseconds: 800)); // just before it leaves

      final seen = await _leaving(t, 'bye');
      _expectSmoothExit(seen);

      await t.pumpAndSettle();
      expect(find.text('bye'), findsNothing);
      expect(_snackBar, findsNothing);
    });

    testWidgets('it slides down into the bottom edge instead of fading', (
      t,
    ) async {
      await pumpApp(t);
      AppToast.success('bye', duration: const Duration(seconds: 1));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 800)); // just before it leaves

      var wentUnder = false;
      for (var i = 0; i < 40 && find.text('bye').evaluate().isNotEmpty; i++) {
        expect(
          _opacity(t, 'bye'),
          closeTo(1, 1e-6),
          reason: 'it faded instead of sliding away',
        );
        if (_visibility(t, 'bye')! <= 0.15) wentUnder = true;
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(wentUnder, isTrue, reason: 'it never went all the way down');
    });

    testWidgets('clear() slides it away too', (t) async {
      await pumpApp(t);
      AppToast.info('cleared');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      AppToast.clear();
      await t.pump();
      _expectSmoothExit(await _leaving(t, 'cleared'));
      await t.pumpAndSettle();
      expect(find.text('cleared'), findsNothing);
    });

    testWidgets('the close button slides it away too', (t) async {
      await pumpApp(t);
      AppToast.error('closing');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      await t.tap(find.byIcon(Icons.close));
      await t.pump();
      _expectSmoothExit(await _leaving(t, 'closing'));
      await t.pumpAndSettle();
      expect(find.text('closing'), findsNothing);
    });

    testWidgets('a new toast takes the place of one that is leaving at once', (
      t,
    ) async {
      await pumpApp(t);
      AppToast.info('old');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      AppToast.clear(); // starts to leave
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('old'), findsOneWidget);

      AppToast.success('new');
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect(find.text('old'), findsNothing);
      expect(find.text('new'), findsOneWidget);
      expect(_snackBar, findsOneWidget);
      await t.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('it stays the full time it was asked for before leaving', (
      t,
    ) async {
      await pumpApp(t);
      AppToast.success('stay', duration: const Duration(seconds: 2));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400)); // entrance done

      // Fully visible for the whole stay, not fading early.
      for (var ms = 0; ms < 1900; ms += 100) {
        expect(
          _visibility(t, 'stay'),
          closeTo(1, 1e-6),
          reason: 'faded early at ${ms}ms of a 2 s stay',
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pumpAndSettle();
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:homeservice/l10n/l10n.dart';
import 'package:homeservice/models/medicine_detail.dart';
import 'package:homeservice/models/medicine_item.dart';
import 'package:homeservice/models/purchase_model.dart';
import 'package:homeservice/models/user.dart';
import 'package:homeservice/repositories/purchase_repository.dart';
import 'package:homeservice/screens/medicine_detail_screen.dart';
import 'package:homeservice/screens/purchase_detail_screen.dart';
import 'package:homeservice/services/purchase_api.dart';
import 'package:homeservice/state/auth_state.dart';
import 'package:homeservice/state/medicine_provider.dart';
import 'package:homeservice/state/purchase_providers.dart';
import 'package:homeservice/widgets/detail_bottom_bar.dart';
import 'package:homeservice/widgets/item_card.dart';
import 'package:homeservice/widgets/more_menu.dart';
import 'package:homeservice/widgets/toast.dart';

import 'package:dio/dio.dart';

import 'support/list_fakes.dart';

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(
        scaffoldMessengerKey: AppToast.messengerKey,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );

class _Auth extends AuthNotifier {
  _Auth(this.id);
  final String id;
  @override
  AuthState build() => AuthState(
    loading: false,
    isAuthenticated: true,
    user: User(id: id, name: 'T', email: 't@x.io'),
  );
}

Purchase _purchase({
  String status = 'planned',
  String requester = 'me',
  String? buyer,
}) => Purchase.fromJson({
  'id': 'p1',
  'title': 'Light bulbs',
  'status': status,
  'requester_id': requester,
  'buyer_id': buyer,
  'currency': 'THB',
  'amount_estimated': 250,
  'created_at': '2026-10-01T10:00:00Z',
  'updated_at': '2026-10-01T10:00:00Z',
});

/// A purchase repository that records what the page asked it to do.
class _Repo extends PurchaseRepository {
  _Repo(this.purchase) : super(PurchaseApi(Dio()));
  Purchase purchase;
  final calls = <String>[];

  @override
  Future<Purchase> getById(String id) async => purchase;

  @override
  Future<Purchase> claim(String id) async {
    calls.add('claim');
    return purchase;
  }

  @override
  Future<Purchase> markBought(String id, {double? amountPaid}) async {
    calls.add('bought $amountPaid');
    return purchase;
  }

  @override
  Future<Purchase> markDelivered(String id) async {
    calls.add('delivered');
    return purchase;
  }

  @override
  Future<Purchase> cancel(String id) async {
    calls.add('cancel');
    return purchase;
  }
}

Future<_Repo> _openPurchase(
  WidgetTester t,
  Purchase p, {
  String me = 'me',
}) async {
  final repo = _Repo(p);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const PurchaseDetailScreen(id: 'p1'),
      ),
      GoRoute(
        path: '/purchases/:id/edit',
        builder: (_, _) => const Scaffold(body: Text('EDIT PAGE')),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => _Auth(me)),
        purchaseRepoProvider.overrideWithValue(repo),
      ],
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
  return repo;
}

void main() {
  group('the shared pieces', () {
    testWidgets('ItemCard draws ">" only when it opens something', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: [
                ItemCard(onTap: () => taps++, child: const Text('opens')),
                const ItemCard(child: Text('static')),
              ],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await t.tap(find.text('opens'));
      expect(taps, 1);
    });

    testWidgets('DetailBottomBar: a wide primary and one alternative', (
      t,
    ) async {
      var primary = 0, secondary = 0;
      await t.pumpWidget(
        _app(
          Scaffold(
            bottomNavigationBar: DetailBottomBar(
              primary: DetailAction(
                label: 'Do it',
                icon: Icons.check,
                onPressed: () => primary++,
              ),
              secondary: DetailAction(
                label: 'Other',
                icon: Icons.add,
                onPressed: () => secondary++,
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Do it'));
      await t.tap(find.text('Other'));
      expect((primary, secondary), (1, 1));
    });

    testWidgets('DetailBottomBar ignores taps while busy', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _app(
          Scaffold(
            bottomNavigationBar: DetailBottomBar(
              primary: DetailAction(
                label: 'Working',
                icon: Icons.check,
                busy: true,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Working'), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('MoreMenuButton lists the actions and runs the chosen one', (
      t,
    ) async {
      final chosen = <String>[];
      await t.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(
              actions: [
                MoreMenuButton(
                  items: [
                    MoreMenuItem(
                      label: 'Edit',
                      icon: Icons.edit,
                      onSelected: () => chosen.add('edit'),
                    ),
                    MoreMenuItem(
                      label: 'Delete',
                      icon: Icons.delete,
                      destructive: true,
                      onSelected: () => chosen.add('delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await t.tap(find.byTooltip('More'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(chosen, ['delete']);
    });

    testWidgets('MoreMenuButton with nothing to offer is not there', (t) async {
      await t.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(actions: const [MoreMenuButton(items: [])]),
          ),
        ),
      );
      expect(find.byTooltip('More'), findsNothing);
    });
  });

  group('every list card says whether it opens', () {
    for (final name in ['Bills', 'Purchases', 'Medicine']) {
      testWidgets('$name: a ">" on each card', (t) async {
        final built = listScreens[name]!(filled: true);
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
        expect(find.byType(ItemCard), findsWidgets);
        expect(
          find.byIcon(Icons.chevron_right_rounded),
          findsNWidgets(find.byType(ItemCard).evaluate().length),
        );
      });
    }

    testWidgets('Notes: only a note with more to read has an arrow, and it '
        'turns instead of pointing right', (t) async {
      final built = listScreens['Notes']!(filled: true);
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
      // Two short notes and one long one: one arrow, no ">".
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await t.tap(find.byIcon(Icons.expand_more_rounded));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
      // A note's other actions are behind the same "⋯" as elsewhere.
      expect(find.byType(MoreMenuButton), findsWidgets);

      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 31));
    });
  });

  group('purchase detail', () {
    testWidgets('a new purchase: take it', (t) async {
      final repo = await _openPurchase(t, _purchase(requester: 'someone'));
      expect(find.text("I'll buy this"), findsOneWidget);
      await t.tap(find.text("I'll buy this"));
      await t.pumpAndSettle();
      expect(repo.calls, ['claim']);
      expect(find.text('Status updated'), findsOneWidget);
    });

    testWidgets('bought by me, ordered: ask what was paid, then mark', (
      t,
    ) async {
      final repo = await _openPurchase(
        t,
        _purchase(status: 'ordered', buyer: 'me'),
      );
      await t.tap(find.text('Mark as bought'));
      await t.pumpAndSettle();
      expect(find.text('How much did you pay?'), findsOneWidget);

      await t.enterText(find.byType(TextField).last, '199.5');
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await t.pumpAndSettle();
      expect(repo.calls, ['bought 199.5']);
    });

    testWidgets('an amount is required to mark as bought', (t) async {
      final repo = await _openPurchase(
        t,
        _purchase(status: 'ordered', buyer: 'me'),
      );
      await t.tap(find.text('Mark as bought'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, '');
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await t.pumpAndSettle();
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('bought: mark as delivered', (t) async {
      final repo = await _openPurchase(
        t,
        _purchase(status: 'bought', buyer: 'me'),
      );
      await t.tap(find.text('Mark as delivered'));
      await t.pumpAndSettle();
      expect(repo.calls, ['delivered']);
    });

    testWidgets('someone else is buying it: nothing to press', (t) async {
      await _openPurchase(t, _purchase(status: 'ordered', buyer: 'another'));
      expect(find.byType(DetailBottomBar), findsNothing);
    });

    testWidgets('a finished purchase has no bottom bar', (t) async {
      await _openPurchase(t, _purchase(status: 'delivered', buyer: 'me'));
      expect(find.byType(DetailBottomBar), findsNothing);
    });

    testWidgets('"⋯" holds edit, attach and cancel for the requester', (
      t,
    ) async {
      await _openPurchase(t, _purchase());
      await t.tap(find.byTooltip('More'));
      await t.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Attach file / photo'), findsOneWidget);
      expect(find.text('Cancel this purchase'), findsOneWidget);
    });

    testWidgets('edit opens the edit page', (t) async {
      await _openPurchase(t, _purchase());
      await t.tap(find.byTooltip('More'));
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      expect(find.text('EDIT PAGE'), findsOneWidget);
    });

    testWidgets('cancelling asks first, and "Keep it" does nothing', (t) async {
      final repo = await _openPurchase(t, _purchase());
      await t.tap(find.byTooltip('More'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel this purchase'));
      await t.pumpAndSettle();
      expect(find.text('Cancel this purchase?'), findsOneWidget);

      await t.tap(find.text('Keep it'));
      await t.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await t.tap(find.byTooltip('More'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel this purchase'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel this purchase'),
        ),
      );
      await t.pumpAndSettle();
      expect(repo.calls, ['cancel']);
    });

    testWidgets('someone with no part in it has no menu', (t) async {
      await _openPurchase(t, _purchase(requester: 'someone', buyer: 'another'));
      expect(find.byTooltip('More'), findsNothing);
    });
  });

  group('medicine detail', () {
    Future<void> open(WidgetTester t) async {
      final detail = MedicineDetail(
        item: MedicineItem(id: 'm1', name: 'Cetirizine', stockQty: 10),
        batches: const [],
      );
      await t.pumpWidget(
        _app(
          const MedicineDetailScreen(id: 'm1'),
          overrides: [
            medicineDetailProvider('m1').overrideWith((ref) async => detail),
          ],
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('the main button takes medicine out (it used to open the '
        'alert settings)', (t) async {
      await open(t);
      await t.tap(find.widgetWithText(FilledButton, 'Take out'));
      await t.pumpAndSettle();

      // The take-out sheet has a quantity and Confirm; the alert sheet has
      // neither.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Set alerts'), findsNothing);
    });

    testWidgets('the other button is stock in', (t) async {
      await open(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Stock in'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('alerts are under "⋯", like every other secondary action', (
      t,
    ) async {
      await open(t);
      await t.tap(find.byTooltip('More'));
      await t.pumpAndSettle();
      await t.tap(find.text('Set alerts'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:homehq/l10n/l10n.dart';
import 'package:homehq/models/spending.dart';
import 'package:homehq/repositories/dashboard_repository.dart';
import 'package:homehq/screens/dashboard_screen.dart';
import 'package:homehq/state/dashboard_provider.dart';
import 'package:homehq/widgets/dashboard/breakdown_bars.dart';
import 'package:homehq/widgets/dashboard/donut_chart.dart';
import 'package:homehq/widgets/dashboard/money.dart';
import 'package:homehq/widgets/dashboard/pace_chart.dart';
import 'package:homehq/widgets/dashboard/sparkline.dart';
import 'package:homehq/widgets/dashboard/trend_chart.dart';
import 'package:homehq/widgets/toast.dart';

/// This month in Thailand, the way the screen works it out, moved by [back]
/// months: "2026-10", "2026-09" ...
String _ym([int back = 0]) {
  final t = DateTime.now().toUtc().add(const Duration(hours: 7));
  final d = DateTime(t.year, t.month - back);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

Spending _spending({
  String? month,
  double bills = 1200,
  double purchases = 450.5,
  double previous = 1500,
  List<SpendSlice>? byType,
  List<SpendSlice>? byCategory,
  double unpaid = 2300,
  double overdue = 0,
  int overdueCount = 0,
  int excluded = 0,
  List<UpcomingBill>? upcoming,
}) {
  final m = month ?? _ym();
  return Spending(
    month: m,
    totalSpent: bills + purchases,
    previousMonth: _ym(1),
    previousSpent: previous,
    billsPaid: bills,
    billsPaidCount: bills > 0 ? 2 : 0,
    billsByType:
        byType ??
        [
          if (bills > 0) ...[
            SpendSlice(key: 'electric', amount: bills * 0.75, count: 1),
            SpendSlice(key: 'water', amount: bills * 0.25, count: 1),
          ],
        ],
    unpaid: unpaid,
    unpaidCount: 2,
    overdue: overdue,
    overdueCount: overdueCount,
    purchasesSpent: purchases,
    purchasesCount: purchases > 0 ? 3 : 0,
    purchasesByCategory:
        byCategory ??
        [
          if (purchases > 0) ...[
            SpendSlice(key: 'food', amount: purchases * 0.8, count: 2),
            SpendSlice(key: 'other', amount: purchases * 0.2, count: 1),
          ],
        ],
    excludedCount: excluded,
    openCount: 1,
    openEstimated: 500,
    trend: [
      for (var i = 5; i >= 0; i--)
        SpendPoint(
          month: _ym(i),
          bills: i == 0 ? bills : 100.0 * (6 - i),
          purchases: i == 0 ? purchases : 50.0 * i,
        ),
    ],
    // 16 days in. This month: 1,000 on the 5th, 450.50 on the 10th, 200 on the
    // 12th (the 1,650.50 of the totals). Last month: 900 on the 3rd, 300 on the
    // 14th, 600 on the 25th.
    throughDay: 16,
    daily: [
      for (var d = 1; d <= 30; d++)
        DayPoint(
          day: d,
          bills: d == 5 ? bills - 200 : (d == 12 ? 200 : 0),
          purchases: d == 10 ? purchases : 0,
        ),
    ],
    previousDaily: [
      for (var d = 1; d <= 30; d++)
        DayPoint(
          day: d,
          bills: d == 3 ? 900 : (d == 25 ? 600 : 0),
          purchases: d == 14 ? 300 : 0,
        ),
    ],
    upcoming:
        upcoming ??
        const [
          UpcomingBill(
            id: 'b1',
            title: 'Electricity',
            type: 'electric',
            amount: 1200,
            daysLeft: -3,
            overdue: true,
          ),
          UpcomingBill(
            id: 'b2',
            title: 'Water',
            type: 'water',
            amount: 350,
            daysLeft: 0,
            overdue: false,
          ),
          UpcomingBill(
            id: 'b3',
            title: 'Internet',
            type: 'internet',
            amount: 599,
            daysLeft: 5,
            overdue: false,
          ),
        ],
  );
}

class _Repo extends DashboardRepository {
  _Repo({Map<String, Spending>? byMonth, this.fail = false})
    : byMonth = byMonth ?? {},
      super(Dio());

  Map<String, Spending> byMonth;
  bool fail;

  /// The month asked for each time (null = the current one).
  final List<String?> asked = [];

  @override
  Future<Spending> spending({String? month}) async {
    asked.add(month);
    if (fail) throw const DashboardException(DashboardFailure.unavailable);
    return byMonth[month ?? _ym()] ?? _spending(month: month ?? _ym());
  }
}

Future<void> _frames(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  WidgetTester t,
  _Repo repo, {
  String locale = 'en',
  Size size = const Size(800, 5600),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);

  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      for (final p in ['/bills', '/purchases', '/home'])
        GoRoute(
          path: p,
          builder: (_, st) => Scaffold(body: Text('page ${st.uri}')),
        ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [dashboardRepoProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        scaffoldMessengerKey: AppToast.messengerKey,
        routerConfig: router,
      ),
    ),
  );
  await _frames(t);
}

void main() {
  group('amounts', () {
    test(
      'baht drops the satang of a whole amount, and keeps them otherwise',
      () {
        expect(baht(1200), '฿1,200');
        expect(baht(450.5), '฿450.50');
        expect(baht(0), '฿0');
      },
    );

    test('compactBaht is short enough for an axis', () {
      expect(compactBaht(0), '0');
      expect(compactBaht(950), '950');
      expect(compactBaht(1200), '1.2K');
      expect(compactBaht(2000), '2K');
      expect(compactBaht(12400), '12K');
      expect(compactBaht(1500000), '1.5M');
    });

    test('niceMax is the next 1, 2 or 5 times a power of ten', () {
      expect(niceMax(0), 100);
      expect(niceMax(1), 1);
      expect(niceMax(3), 5);
      expect(niceMax(8), 10);
      expect(niceMax(130), 200);
      expect(niceMax(4300), 5000);
      expect(niceMax(5000), 5000);
      expect(niceMax(5001), 10000);
    });
  });

  group('the model', () {
    test('reads the server answer, and a missing part as zero', () {
      final s = Spending.fromJson({
        'month': '2026-10',
        'total_spent': 580.5,
        'previous_month': '2026-09',
        'previous_spent': 50,
        'bills': {
          'paid': 350.5,
          'paid_count': 2,
          'by_type': [
            {'key': 'electric', 'amount': 250.5, 'count': 1},
          ],
          'unpaid': 88,
          'unpaid_count': 2,
          'overdue': 11,
          'overdue_count': 1,
        },
        'purchases': {'spent': 230, 'count': 3, 'excluded_count': 1},
        'trend': [
          {'month': '2026-09', 'bills': 40, 'purchases': 10, 'total': 50},
        ],
        'upcoming': [
          {
            'id': 'x',
            'title': 'Water',
            'type': 'water',
            'amount': 350,
            'days_left': -2,
            'overdue': true,
          },
        ],
      });
      expect(s.billsPaid, 350.5);
      expect(s.billsByType.single.key, 'electric');
      expect(s.purchasesByCategory, isEmpty, reason: 'absent means none');
      expect(s.excludedCount, 1);
      expect(s.trend.single.total, 50);
      expect(s.upcoming.single.overdue, isTrue);
      expect(s.changePercent, 1061);
      expect(Spending.fromJson(const {}).isEmpty, isTrue);
    });

    test('there is no change to speak of without a month before', () {
      expect(_spending(previous: 0).changePercent, isNull);
      expect(
        _spending(bills: 1000, purchases: 0, previous: 1000).changePercent,
        0,
      );
      expect(
        _spending(bills: 500, purchases: 0, previous: 1000).changePercent,
        -50,
      );
    });
  });

  group('the repository', () {
    test(
      'asks for the month, and says when the server has no dashboard',
      () async {
        late RequestOptions seen;
        final ok = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (o, h) {
                seen = o;
                h.resolve(
                  Response(
                    requestOptions: o,
                    statusCode: 200,
                    data: {'month': '2026-09'},
                  ),
                );
              },
            ),
          );
        final s = await DashboardRepository(ok).spending(month: '2026-09');
        expect(seen.path, '/dashboard/spending');
        expect(seen.queryParameters, {'month': '2026-09'});
        expect(s.month, '2026-09');

        final old = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (o, h) => h.reject(
                DioException(
                  requestOptions: o,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: o, statusCode: 404),
                ),
              ),
            ),
          );
        await expectLater(
          DashboardRepository(old).spending(),
          throwsA(
            isA<DashboardException>().having(
              (e) => e.failure,
              'failure',
              DashboardFailure.unsupported,
            ),
          ),
        );
      },
    );
  });

  group('the screen', () {
    testWidgets('leads with what was spent, and how that compares', (t) async {
      await _open(t, _Repo());
      expect(
        t.widget<Text>(find.byKey(const ValueKey('hero'))).data,
        '฿1,650.50',
      );
      // 1650.5 against 1500 is up 10%.
      expect(find.textContaining('Up 10% on'), findsOneWidget);
      // The split by feature, with the legend words in ink.
      expect(find.text('Bills paid'), findsOneWidget);
      expect(find.text('฿1,200'), findsWidgets);
      expect(find.text('Bought'), findsOneWidget);
      expect(find.text('฿450.50'), findsWidgets);
    });

    testWidgets(
      'says "down" and "the same" too, and what to compare with is gone',
      (t) async {
        await _open(
          t,
          _Repo(
            byMonth: {
              _ym(): _spending(bills: 500, purchases: 0, previous: 1000),
            },
          ),
        );
        expect(find.textContaining('Down 50% on'), findsOneWidget);

        await _open(
          t,
          _Repo(
            byMonth: {
              _ym(): _spending(bills: 1000, purchases: 0, previous: 1000),
            },
          ),
        );
        expect(find.textContaining('The same as'), findsOneWidget);

        await _open(t, _Repo(byMonth: {_ym(): _spending(previous: 0)}));
        expect(find.textContaining('Nothing was spent in'), findsOneWidget);
      },
    );

    testWidgets('still to pay, and overdue with an icon and words', (t) async {
      await _open(
        t,
        _Repo(byMonth: {_ym(): _spending(overdue: 1200, overdueCount: 1)}),
      );
      expect(find.text('Still to pay'), findsOneWidget);
      expect(find.text('฿2,300'), findsOneWidget);
      final overdue = find.byKey(const ValueKey('overdue'));
      expect(
        find.descendant(of: overdue, matching: find.text('฿1,200')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: overdue,
          matching: find.byIcon(Icons.error_rounded),
        ),
        findsOneWidget,
        reason: 'late is never colour alone',
      );
    });

    testWidgets('nothing overdue is said, with a tick', (t) async {
      await _open(t, _Repo());
      final overdue = find.byKey(const ValueKey('overdue'));
      expect(
        find.descendant(of: overdue, matching: find.text('Nothing overdue')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: overdue,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lists the next bills: late, today and later', (t) async {
      await _open(t, _Repo());
      expect(find.text('Next bills to pay'), findsOneWidget);
      expect(find.textContaining('Overdue by 3 days'), findsOneWidget);
      expect(find.textContaining('Due today'), findsOneWidget);
      expect(find.textContaining('Due in 5 days'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsWidgets);
      // The bill type is worded in the language in use.
      expect(find.textContaining('Electricity ·'), findsOneWidget);
    });

    testWidgets('breaks the month down by bill type and purchase category', (
      t,
    ) async {
      await _open(t, _Repo());
      expect(find.text('Bills paid, by type'), findsOneWidget);
      expect(find.text('Electricity'), findsWidgets);
      expect(find.text('Water'), findsWidgets);
      expect(find.text('Bought, by category'), findsOneWidget);
      expect(find.text('food'), findsOneWidget);
      expect(
        find.text('No category'),
        findsOneWidget,
        reason: '"other" is worded',
      );
    });

    testWidgets('a month with nothing in it still looks like a dashboard', (
      t,
    ) async {
      await _open(
        t,
        _Repo(
          byMonth: {
            _ym(): Spending.fromJson({
              'month': _ym(),
              'previous_month': _ym(1),
            }),
          },
        ),
      );
      expect(t.widget<Text>(find.byKey(const ValueKey('hero'))).data, '฿0');
      expect(
        find.text(
          'Pay a bill or mark a purchase as bought and it shows up here.',
        ),
        findsOneWidget,
      );
      // The frames are there, drawn at zero, and say what to do.
      expect(find.byType(SpendingTrendChart), findsOneWidget);
      expect(find.byType(SpendingPaceChart), findsOneWidget);
      expect(find.byType(BillTypeDonut), findsOneWidget);
      expect(
        find.text(
          'Nothing yet. Pay a bill or mark a purchase as bought and it appears here.',
        ),
        findsOneWidget,
      );
      expect(find.text('No bills paid this month'), findsOneWidget);
      expect(find.text('Nothing bought this month'), findsOneWidget);
    });

    testWidgets('words one thing in the singular', (t) async {
      await _open(
        t,
        _Repo(
          byMonth: {
            _ym(): _spending(overdue: 640, overdueCount: 1, excluded: 1),
          },
        ),
      );
      final overdue = find.byKey(const ValueKey('overdue'));
      expect(
        find.descendant(of: overdue, matching: find.text('1 bill')),
        findsOneWidget,
      );
      expect(
        find.text('1 purchase in another currency is not included'),
        findsOneWidget,
      );
    });

    testWidgets('shows what is planned to buy, when something is', (t) async {
      await _open(t, _Repo());
      final planned = find.byKey(const ValueKey('planned'));
      expect(
        find.descendant(of: planned, matching: find.text('Planned purchases')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: planned, matching: find.text('฿500')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: planned, matching: find.text('1 item')),
        findsOneWidget,
      );
    });

    testWidgets('says how many purchases were left out for their currency', (
      t,
    ) async {
      await _open(t, _Repo(byMonth: {_ym(): _spending(excluded: 2)}));
      expect(
        find.text('2 purchases in another currency are not included'),
        findsOneWidget,
      );
    });

    testWidgets('the arrows move between months and back to this one', (
      t,
    ) async {
      final repo = _Repo();
      await _open(t, repo);
      expect(repo.asked, [null]);
      // There is nothing after the current month.
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
            )
            .onPressed,
        isNull,
      );

      await t.tap(find.byTooltip('Previous month'));
      await _frames(t);
      expect(repo.asked.last, _ym(1));
      expect(find.text('This month'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
            )
            .onPressed,
        isNotNull,
      );

      await t.tap(find.byTooltip('Next month'));
      await _frames(t);
      expect(
        repo.asked.last,
        isNull,
        reason: 'the current month is "no month"',
      );
      expect(find.text('This month'), findsNothing);
    });

    testWidgets('tapping a column chooses that month', (t) async {
      final repo = _Repo();
      await _open(t, repo);
      final rect = t.getRect(find.byType(SpendingTrendChart));
      // Six columns between the y-axis words and the right edge.
      final slot = (rect.width - 38 - 6) / 6;
      final second = Offset(rect.left + 38 + slot * 1.5, rect.top + 100);

      await t.tapAt(second);
      await _frames(t);
      expect(repo.asked.last, _ym(4), reason: 'the second of the six months');
    });

    testWidgets('the table twin carries every value', (t) async {
      await _open(t, _Repo());
      expect(find.byKey(const ValueKey('trend-table')), findsNothing);

      await t.tap(find.byTooltip('Table'));
      await _frames(t);
      final table = find.byKey(const ValueKey('trend-table'));
      expect(table, findsOneWidget);
      expect(find.byType(SpendingTrendChart), findsNothing);
      expect(
        find.descendant(of: table, matching: find.text('Total')),
        findsOneWidget,
      );
      // This month's row: bills, purchases and their sum.
      for (final v in ['฿1,200', '฿450.50', '฿1,650.50']) {
        expect(
          find.descendant(of: table, matching: find.text(v)),
          findsOneWidget,
          reason: v,
        );
      }

      await t.tap(find.byTooltip('Chart'));
      await _frames(t);
      expect(find.byType(SpendingTrendChart), findsOneWidget);
    });

    testWidgets('the pace chart says how this month compares at the same day', (
      t,
    ) async {
      await _open(t, _Repo());
      expect(find.byType(SpendingPaceChart), findsOneWidget);
      expect(find.text('Spending pace'), findsOneWidget);
      // By day 16 this month has spent 1,650.50; last month had spent 1,200.
      final note = find.byKey(const ValueKey('pace-insight'));
      expect(
        find.descendant(
          of: note,
          matching: find.textContaining('By day 16: ฿1,650.50'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: note,
          matching: find.textContaining(
            '฿450.50 more than at this point last month',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and says less, or the same', (t) async {
      // Last month had spent 1,650.50 by now as well.
      final repo = _Repo(
        byMonth: {
          _ym(): () {
            final s = _spending();
            return Spending(
              month: s.month,
              totalSpent: s.totalSpent,
              previousMonth: s.previousMonth,
              previousSpent: s.previousSpent,
              billsPaid: s.billsPaid,
              billsPaidCount: s.billsPaidCount,
              billsByType: s.billsByType,
              unpaid: s.unpaid,
              unpaidCount: s.unpaidCount,
              overdue: s.overdue,
              overdueCount: s.overdueCount,
              purchasesSpent: s.purchasesSpent,
              purchasesCount: s.purchasesCount,
              purchasesByCategory: s.purchasesByCategory,
              excludedCount: s.excludedCount,
              openCount: s.openCount,
              openEstimated: s.openEstimated,
              trend: s.trend,
              upcoming: s.upcoming,
              throughDay: 16,
              daily: s.daily,
              previousDaily: [
                for (var d = 1; d <= 30; d++)
                  DayPoint(day: d, bills: d == 2 ? 2000.5 : 0),
              ],
            );
          }(),
        },
      );
      await _open(t, repo);
      // This month 1,650.50 against 2,000.50: 350 less.
      expect(
        find.textContaining('฿350 less than at this point last month'),
        findsOneWidget,
      );
    });

    testWidgets('puts the bill types in a ring, in a fixed order, with a list', (
      t,
    ) async {
      await _open(t, _Repo());
      expect(find.byType(BillTypeDonut), findsOneWidget);
      expect(
        find.text('Paid'),
        findsOneWidget,
        reason: 'the ring says what it counts',
      );
      // The list names each type with its amount and share (900 and 300 of 1,200).
      expect(find.text('฿900'), findsWidgets);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      // Electricity comes before water whatever their sizes.
      final e = t.getTopLeft(find.text('Electricity').last).dy;
      final w = t.getTopLeft(find.text('Water').last).dy;
      expect(e, lessThan(w));
    });

    testWidgets('touching the pace chart reads that day in words', (t) async {
      await _open(t, _Repo());
      final rect = t.getRect(find.byType(SpendingPaceChart));
      // 30 days, the plot between the amounts on the left and a margin.
      Offset onDay(int d) => Offset(
        rect.left + 38 + (rect.width - 38 - 14) * (d - 1) / 29,
        rect.top + 90,
      );
      final readout = find.byKey(const ValueKey('pace-insight'));

      // Day 12: 1,650.50 so far; last month had spent 900 by then.
      await t.tapAt(onDay(12));
      await _frames(t, 2);
      expect(
        find.descendant(
          of: readout,
          matching: find.text('Day 12: ฿1,650.50 · last month ฿900'),
        ),
        findsOneWidget,
      );

      // A day still to come: only last month has an answer (900 + 300).
      await t.tapAt(onDay(20));
      await _frames(t, 2);
      expect(
        find.descendant(
          of: readout,
          matching: find.text('Day 20: last month ฿1,200'),
        ),
        findsOneWidget,
      );

      // Dragging along it keeps reading.
      await t.dragFrom(onDay(3), const Offset(150, 0));
      await _frames(t, 2);
      expect(
        find.descendant(of: readout, matching: find.textContaining('Day ')),
        findsOneWidget,
      );
    });

    testWidgets('a part of the ring can be held up, by touch or by its row', (
      t,
    ) async {
      await _open(t, _Repo());
      final center = find.byKey(const ValueKey('donut-center'));
      expect(
        t.widget<Text>(center).data,
        '฿1,200',
        reason: 'the total, at first',
      );

      // Its row.
      await t.tap(find.byKey(const ValueKey('type-water')));
      await _frames(t, 2);
      expect(t.widget<Text>(center).data, '฿300');
      // Again lets go.
      await t.tap(find.byKey(const ValueKey('type-water')));
      await _frames(t, 2);
      expect(t.widget<Text>(center).data, '฿1,200');

      // The ring itself: electric is the first 75%, water the last 25%, which
      // sits between nine and twelve o'clock.
      final ring = t.getTopLeft(find.byType(BillTypeDonut));
      await t.tapAt(ring + const Offset(28.5, 28.5));
      await _frames(t, 2);
      expect(t.widget<Text>(center).data, '฿300');
      await t.tapAt(ring + const Offset(104, 66)); // three o'clock: electric
      await _frames(t, 2);
      expect(t.widget<Text>(center).data, '฿900');
    });

    testWidgets('the charts draw in, then stand still', (t) async {
      await _open(t, _Repo());
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the number carries a small trend line', (t) async {
      await _open(t, _Repo());
      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('can be reached from bills and purchases', (t) async {
      await _open(t, _Repo());
      await t.tap(find.text('View all').at(0));
      await _frames(t);
      expect(find.text('page /bills'), findsOneWidget);
    });

    testWidgets('a failure says so and can be retried', (t) async {
      final repo = _Repo(fail: true);
      await _open(t, repo);
      expect(find.text("Couldn't load the spending figures"), findsOneWidget);

      repo.fail = false;
      await t.tap(find.text('Try again'));
      await _frames(t);
      expect(find.byKey(const ValueKey('hero')), findsOneWidget);
    });

    testWidgets('speaks Thai', (t) async {
      await _open(t, _Repo(), locale: 'th');
      expect(find.text('ค้างจ่าย'), findsOneWidget);
      expect(find.text('6 เดือนล่าสุด'), findsOneWidget);
      expect(find.text('ไม่มีบิลเลยกำหนด'), findsOneWidget);
      expect(find.textContaining('เลยกำหนด 3 วัน'), findsOneWidget);
      expect(find.text('ค่าไฟ'), findsWidgets);
    });

    testWidgets('fits a small phone with large text', (t) async {
      await _open(t, _Repo(), size: const Size(640, 5200));
      expect(t.takeException(), isNull);
    });
  });

  group('the ring and the running total', () {
    test(
      'parts keep a fixed order, an unknown type is "other", empty ones go',
      () {
        final out = BillTypeDonut.ordered(const [
          SpendSlice(key: 'phone', amount: 50),
          SpendSlice(key: 'gas', amount: 30), // not one of ours
          SpendSlice(key: 'electric', amount: 400),
          SpendSlice(key: 'other', amount: 20),
          SpendSlice(key: 'water', amount: 0),
        ]);
        expect(out.map((e) => e.key), ['electric', 'phone', 'other']);
        expect(out.last.amount, 50, reason: 'gas folded into other: 30 + 20');
      },
    );

    test('every type has its own colour, and an unknown one is grey', () {
      final colours = {for (final k in kBillTypeOrder) billTypeColor(k)};
      expect(colours.length, kBillTypeOrder.length);
      expect(billTypeColor('gas'), billTypeColor('other'));
    });

    test('runningTotal adds day by day', () {
      expect(
        Spending.runningTotal(const [
          DayPoint(day: 1, bills: 10),
          DayPoint(day: 2),
          DayPoint(day: 3, purchases: 5.5),
        ]),
        [10, 10, 15.5],
      );
      expect(Spending.runningTotal(const []), isEmpty);
    });
  });

  group('the breakdown bars', () {
    Future<void> show(
      WidgetTester t,
      List<SpendSlice> slices, {
      int maxRows = 6,
    }) {
      return t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: BreakdownBars(
                slices: slices,
                color: kBillsColor,
                labelFor: (k) => 'name $k',
                otherLabel: 'the rest',
                maxRows: maxRows,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('longest first, one row per part', (t) async {
      await show(t, [
        const SpendSlice(key: 'a', amount: 10),
        const SpendSlice(key: 'b', amount: 300),
        const SpendSlice(key: 'c', amount: 40),
      ]);
      final b = t.getTopLeft(find.text('name b')).dy;
      final c = t.getTopLeft(find.text('name c')).dy;
      final a = t.getTopLeft(find.text('name a')).dy;
      expect(b, lessThan(c));
      expect(c, lessThan(a));
    });

    testWidgets('folds a long tail into one row that adds it up', (t) async {
      await show(t, [
        for (var i = 1; i <= 9; i++) SpendSlice(key: 'k$i', amount: i * 10.0),
      ]);
      expect(find.text('the rest'), findsOneWidget);
      // k4..k1 are folded: 40+30+20+10 = 100.
      expect(find.text('฿100'), findsOneWidget);
      expect(find.text('name k1'), findsNothing);
      expect(find.text('name k9'), findsOneWidget);
    });
  });
}

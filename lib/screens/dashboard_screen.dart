import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../l10n/labels.dart';
import '../models/spending.dart';
import '../shared/app_colors.dart';
import '../state/dashboard_provider.dart';
import '../widgets/dashboard/breakdown_bars.dart';
import '../widgets/dashboard/donut_chart.dart';
import '../widgets/dashboard/money.dart';
import '../widgets/dashboard/pace_chart.dart';
import '../widgets/dashboard/sparkline.dart';
import '../widgets/dashboard/trend_chart.dart';
import '../widgets/error_state.dart';
import '../widgets/page_loading.dart';
import '../widgets/top_nav_bar.dart';

/// Where the money went: what the bills and purchases features add up to.
///
/// It leads with one number (what was spent in the month), then what is still
/// owed, six months of trend, where the month's money went, and which bills
/// are next. Pick another month with the arrows or by tapping a column.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// The last figures shown, kept (dimmed) while the next month loads, so the
  /// page never flashes empty.
  Spending? _last;
  bool _table = false;

  /// This month in Thailand, as "YYYY-MM".
  static String _currentMonth() {
    final t = DateTime.now().toUtc().add(const Duration(hours: 7));
    return '${t.year}-${t.month.toString().padLeft(2, '0')}';
  }

  /// A "YYYY-MM" as a date. A month the server left out or garbled is read as
  /// this month, so the page still draws.
  static DateTime _date(String ym) {
    final p = ym.split('-');
    final y = p.length == 2 ? int.tryParse(p[0]) : null;
    final m = p.length == 2 ? int.tryParse(p[1]) : null;
    if (y == null || m == null || m < 1 || m > 12) return DateTime.now();
    return DateTime(y, m);
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// The month before [d]'s: from the answer, or counted back from the one on
  /// show when the answer left it out.
  String _previousKey(Spending d, String shown) => d.previousMonth.isNotEmpty
      ? d.previousMonth
      : _key(DateTime(_date(shown).year, _date(shown).month - 1));

  String _monthName(BuildContext context, String ym, {bool short = false}) {
    final locale = Localizations.localeOf(context).toString();
    final d = _date(ym);
    return short
        ? DateFormat.MMM(locale).format(d)
        : DateFormat.yMMMM(locale).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final picked = ref.watch(dashboardMonthProvider);
    final async = ref.watch(spendingProvider(picked));
    final data = async.value ?? _last;
    if (async.value != null) _last = async.value;

    final shown = data?.month ?? picked ?? _currentMonth();
    final isCurrent = shown == _currentMonth();

    Widget body;
    if (data == null) {
      body = async.hasError
          ? ErrorState(
              icon: Icons.error_outline,
              title: l10n.dashLoadFailed,
              onRetry: () => ref.invalidate(spendingProvider(picked)),
            )
          : const PageLoading();
    } else {
      body = AnimatedOpacity(
        opacity: async.isLoading ? 0.5 : 1,
        duration: const Duration(milliseconds: 150),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(spendingProvider(picked));
            await ref.read(spendingProvider(picked).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _MonthBar(
                label: _monthName(context, shown),
                canGoNext: !isCurrent,
                onPrev: () => ref
                    .read(dashboardMonthProvider.notifier)
                    .pick(
                      _key(DateTime(_date(shown).year, _date(shown).month - 1)),
                    ),
                onNext: () => ref
                    .read(dashboardMonthProvider.notifier)
                    .pick(
                      _key(
                                DateTime(
                                  _date(shown).year,
                                  _date(shown).month + 1,
                                ),
                              ) ==
                              _currentMonth()
                          ? null
                          : _key(
                              DateTime(
                                _date(shown).year,
                                _date(shown).month + 1,
                              ),
                            ),
                    ),
                onToday: isCurrent
                    ? null
                    : () =>
                          ref.read(dashboardMonthProvider.notifier).pick(null),
              ),
              const SizedBox(height: 12),
              _Hero(
                data: data,
                monthName: _monthName(context, shown),
                prevName: _monthName(context, _previousKey(data, shown)),
              ),
              const SizedBox(height: 12),
              _Owed(data: data),
              const SizedBox(height: 12),
              _Pace(
                data: data,
                nowName: _monthName(context, shown),
                prevName: _monthName(context, _previousKey(data, shown)),
              ),
              const SizedBox(height: 12),
              _Trend(
                data: data,
                table: _table,
                onToggle: (t) => setState(() => _table = t),
                shortName: (ym) => _monthName(context, ym, short: true),
                longName: (ym) => _monthName(context, ym),
                onSelect: (ym) => ref
                    .read(dashboardMonthProvider.notifier)
                    .pick(ym == _currentMonth() ? null : ym),
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.dashBills,
                total: data.billsPaid,
                color: kBillsColor,
                onViewAll: () => context.push('/bills'),
                heading: l10n.dashByType,
                child: data.billsByType.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BillTypeDonut(
                            slices: const [],
                            centerLabel: l10n.dashDonutCenter,
                            nameFor: (k) => billTypeLabel(l10n, k),
                            semanticsLabel: l10n.dashNoBillsPaid,
                          ),
                          const SizedBox(height: 8),
                          _None(l10n.dashNoBillsPaid),
                        ],
                      )
                    : BillTypeDonut(
                        animationKey: data.month,
                        slices: data.billsByType,
                        centerLabel: l10n.dashDonutCenter,
                        nameFor: (k) => billTypeLabel(l10n, k),
                        semanticsLabel: [
                          for (final s in BillTypeDonut.ordered(
                            data.billsByType,
                          ))
                            '${billTypeLabel(l10n, s.key)} ${baht(s.amount)}',
                        ].join(', '),
                      ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.dashPurchases,
                total: data.purchasesSpent,
                color: kPurchasesColor,
                onViewAll: () => context.push('/purchases'),
                heading: l10n.dashByCategory,
                child: data.purchasesByCategory.isEmpty
                    ? _None(l10n.dashNoPurchases)
                    : BreakdownBars(
                        slices: data.purchasesByCategory,
                        color: kPurchasesColor,
                        labelFor: (k) =>
                            k == 'other' ? l10n.dashCategoryOther : k,
                        otherLabel: l10n.dashCategoryOther,
                      ),
              ),
              if (data.excludedCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.dashExcluded(data.excludedCount),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Upcoming(data: data, onViewAll: () => context.push('/bills')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgSoft,
      appBar: TopNavBar(
        // A feature name: not translated (see the home screen).
        title: 'Spending Dashboard',
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      body: body,
    );
  }
}

// ── pieces ──────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = 16});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: child,
  );
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final String label;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        IconButton(
          tooltip: l10n.dashPrevMonth,
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                key: const ValueKey('month-label'),
                style: const TextStyle(
                  color: AppColors.deepNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (onToday != null)
                GestureDetector(
                  onTap: onToday,
                  child: Text(
                    l10n.dashThisMonth,
                    style: const TextStyle(
                      color: AppColors.softBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.dashNextMonth,
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// The one number the page leads with.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.data,
    required this.monthName,
    required this.prevName,
  });

  final Spending data;
  final String monthName;
  final String prevName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pct = data.changePercent;

    String deltaText() {
      if (pct == null) return l10n.dashNoPrev(prevName);
      if (pct == 0) return l10n.dashSame(prevName);
      return pct > 0
          ? l10n.dashUp('$pct', prevName)
          : l10n.dashDown('${pct.abs()}', prevName);
    }

    final deltaIcon = pct == null || pct == 0
        ? Icons.remove_rounded
        : (pct > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

    return _Card(
      padding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dashSpentIn(monthName),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 6),
          // The hero figure: big, in the app's own face, proportional digits.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    baht(data.totalSpent),
                    key: const ValueKey('hero'),
                    style: const TextStyle(
                      color: AppColors.deepNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 48,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              if (data.trend.length >= 2) ...[
                const SizedBox(width: 12),
                Sparkline(values: [for (final p in data.trend) p.total]),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(deltaIcon, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  deltaText(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data.isEmpty)
            Text(
              l10n.dashEmptyHint,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else ...[
            _SplitBar(bills: data.billsPaid, purchases: data.purchasesSpent),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Key(
                    color: kBillsColor,
                    label: l10n.dashBillsPaid,
                    value: baht(data.billsPaid),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Key(
                    color: kPurchasesColor,
                    label: l10n.dashBought,
                    value: baht(data.purchasesSpent),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A bar split in two by what was spent: 2 px of surface between the parts.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.bills, required this.purchases});
  final double bills;
  final double purchases;

  @override
  Widget build(BuildContext context) {
    final total = bills + purchases;
    if (total <= 0) return const SizedBox.shrink();
    final b = (bills / total * 1000).round();
    final p = 1000 - b;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Row(
        children: [
          if (b > 0)
            Expanded(
              flex: b,
              child: Container(height: 10, color: kBillsColor),
            ),
          if (b > 0 && p > 0) const SizedBox(width: 2),
          if (p > 0)
            Expanded(
              flex: p,
              child: Container(height: 10, color: kPurchasesColor),
            ),
        ],
      ),
    );
  }
}

/// A legend entry: the swatch carries the colour, the words stay in ink.
class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(top: 4),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.deepNavy,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// What is still owed: the unpaid bills, how much of it is late, and what is
/// planned to buy.
class _Owed extends StatelessWidget {
  const _Owed({required this.data});
  final Spending data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final late = data.overdueCount > 0;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Stat(
                  label: l10n.dashStillToPay,
                  value: baht(data.unpaid),
                  detail: l10n.dashBillCount(data.unpaidCount),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  key: const ValueKey('overdue'),
                  label: l10n.dashOverdue,
                  value: late ? baht(data.overdue) : '—',
                  // Status: an icon and words, never the colour alone.
                  icon: late ? Icons.error_rounded : Icons.check_circle_rounded,
                  iconColor: late ? kCriticalColor : kGoodColor,
                  detail: late
                      ? l10n.dashBillCount(data.overdueCount)
                      : l10n.dashNoneOverdue,
                ),
              ),
            ],
          ),
        ),
        if (data.openCount > 0) ...[
          const SizedBox(height: 12),
          _Stat(
            key: const ValueKey('planned'),
            label: l10n.dashPlanned,
            value: baht(data.openEstimated),
            detail: l10n.dashItemCount(data.openCount),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final String detail;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.deepNavy,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
      ],
    ),
  );
}

class _Trend extends StatelessWidget {
  const _Trend({
    required this.data,
    required this.table,
    required this.onToggle,
    required this.shortName,
    required this.longName,
    required this.onSelect,
  });

  final Spending data;
  final bool table;
  final ValueChanged<bool> onToggle;
  final String Function(String ym) shortName;
  final String Function(String ym) longName;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final i = data.trend.indexWhere((p) => p.month == data.month);
    final peak = data.trend.fold<double>(
      0,
      (m, p) => p.total > m ? p.total : m,
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dashTrendTitle,
                  style: const TextStyle(
                    color: AppColors.deepNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    tooltip: l10n.dashChartView,
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.table_rows_rounded, size: 18),
                    tooltip: l10n.dashTableView,
                  ),
                ],
                selected: {table},
                onSelectionChanged: (s) => onToggle(s.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Two series: the legend is always there.
          Row(
            children: [
              _LegendDot(color: kBillsColor, label: l10n.dashBills),
              const SizedBox(width: 16),
              _LegendDot(color: kPurchasesColor, label: l10n.dashPurchases),
            ],
          ),
          const SizedBox(height: 10),
          if (table && peak > 0)
            _TrendTable(data: data, name: longName)
          else ...[
            SpendingTrendChart(
              points: data.trend,
              selected: i,
              labels: [for (final p in data.trend) shortName(p.month)],
              onSelect: (idx) => onSelect(data.trend[idx].month),
              animationKey: data.month,
              semanticsLabel: [
                for (final p in data.trend)
                  l10n.dashChartLabel(
                    longName(p.month),
                    baht(p.bills),
                    baht(p.purchases),
                  ),
              ].join('. '),
            ),
            if (peak <= 0) _None(l10n.dashTrendEmpty),
          ],
        ],
      ),
    );
  }
}

/// This month's running total against last month's, day by day. Touch or drag
/// on the chart to read a day.
class _Pace extends StatefulWidget {
  const _Pace({
    required this.data,
    required this.nowName,
    required this.prevName,
  });
  final Spending data;

  /// The two months, named: the lines are those months, not "this" and "last".
  final String nowName;
  final String prevName;

  @override
  State<_Pace> createState() => _PaceState();
}

class _PaceState extends State<_Pace> {
  /// The day being read (1-based), or null.
  int? _day;

  @override
  void didUpdateWidget(_Pace old) {
    super.didUpdateWidget(old);
    if (old.data.month != widget.data.month) _day = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = widget.data;
    final now = Spending.runningTotal(data.daily);
    final prev = Spending.runningTotal(data.previousDaily);
    final upTo = data.throughDay.clamp(0, now.length);
    double prevAt(int day) =>
        prev.isEmpty ? 0 : prev[(day - 1).clamp(0, prev.length - 1)];

    // At the same point of last month: its total as far as this month has got.
    String? insight;
    if (upTo > 0) {
      final diff = now[upTo - 1] - prevAt(upTo);
      insight = diff.abs() < 0.5
          ? l10n.dashPaceSame
          : (diff > 0
                ? l10n.dashPaceMore(baht(diff))
                : l10n.dashPaceLess(baht(-diff)));
    }

    // The day being read, in words (the chart only marks it).
    String? readout;
    final d = _day;
    if (d != null) {
      readout = d <= upTo
          ? l10n.dashPaceAt(d, baht(now[d - 1]), baht(prevAt(d)))
          : (d <= prev.length ? l10n.dashPaceAtPrev(d, baht(prevAt(d))) : null);
    }
    final line =
        readout ??
        (insight == null
            ? null
            : '${l10n.dashPaceNow(upTo, baht(now[upTo - 1]))} · $insight');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dashPaceTitle,
            style: const TextStyle(
              color: AppColors.deepNavy,
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.dashPaceSub,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _LineKey(color: kPaceNowColor, label: widget.nowName),
              _LineKey(color: kPacePrevColor, label: widget.prevName),
            ],
          ),
          const SizedBox(height: 8),
          SpendingPaceChart(
            current: now,
            previous: prev,
            throughDay: data.throughDay,
            touchDay: _day,
            onTouch: (day) => setState(() => _day = day),
            animationKey: data.month,
            semanticsLabel: l10n.dashPaceLabel(
              baht(upTo > 0 ? now[upTo - 1] : 0),
              baht(upTo > 0 ? prevAt(upTo) : 0),
            ),
          ),
          if (line != null) ...[
            const SizedBox(height: 8),
            Row(
              key: const ValueKey('pace-insight'),
              children: [
                Icon(
                  readout != null
                      ? Icons.touch_app_rounded
                      : Icons.trending_up_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A legend entry for a line: a short stroke in the line's colour, the words
/// in ink.
class _LineKey extends StatelessWidget {
  const _LineKey({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
      ),
    ],
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
      ),
    ],
  );
}

/// The chart's twin: every value, as words.
class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.data, required this.name});
  final Spending data;
  final String Function(String ym) name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    TextStyle head() => const TextStyle(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );
    Widget cell(String text, {bool bold = false, bool right = true}) =>
        Expanded(
          child: Text(
            text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: bold ? AppColors.deepNavy : AppColors.textMain,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              fontSize: 13,
              // Numbers that must line up in a column.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );

    return Column(
      key: const ValueKey('trend-table'),
      children: [
        Row(
          children: [
            Expanded(flex: 2, child: Text(l10n.dashColMonth, style: head())),
            Expanded(
              child: Text(
                l10n.dashBills,
                textAlign: TextAlign.right,
                style: head(),
              ),
            ),
            Expanded(
              child: Text(
                l10n.dashPurchases,
                textAlign: TextAlign.right,
                style: head(),
              ),
            ),
            Expanded(
              child: Text(
                l10n.dashColTotal,
                textAlign: TextAlign.right,
                style: head(),
              ),
            ),
          ],
        ),
        const Divider(height: 16),
        for (final p in data.trend.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    name(p.month),
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: p.month == data.month
                          ? FontWeight.w800
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                cell(baht(p.bills)),
                cell(baht(p.purchases)),
                cell(baht(p.total), bold: true),
              ],
            ),
          ),
      ],
    );
  }
}

/// A feature's part of the month: its total, its split, and a way into it.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.total,
    required this.color,
    required this.heading,
    required this.child,
    required this.onViewAll,
  });

  final String title;
  final double total;
  final Color color;
  final String heading;
  final Widget child;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title · ${baht(total)}',
                  style: const TextStyle(
                    color: AppColors.deepNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: Text(l10n.dashViewAll)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            heading,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _None extends StatelessWidget {
  const _None(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
  );
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.data, required this.onViewAll});
  final Spending data;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Late and soon get a status mark with words; the rest is plain ink.
    (IconData?, Color?, String) when(UpcomingBill b) {
      if (b.overdue) {
        return (
          Icons.error_rounded,
          kCriticalColor,
          l10n.dashOverdueBy(b.daysLeft.abs() == 0 ? 1 : b.daysLeft.abs()),
        );
      }
      if (b.daysLeft == 0) {
        return (Icons.schedule_rounded, kWarningColor, l10n.dashDueToday);
      }
      if (b.daysLeft == 1) {
        return (Icons.schedule_rounded, kWarningColor, l10n.dashDueTomorrow);
      }
      if (b.daysLeft <= 3) {
        return (
          Icons.schedule_rounded,
          kWarningColor,
          l10n.dashDueIn(b.daysLeft),
        );
      }
      return (null, null, l10n.dashDueIn(b.daysLeft));
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dashUpcomingTitle,
                  style: const TextStyle(
                    color: AppColors.deepNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: Text(l10n.dashViewAll)),
            ],
          ),
          if (data.upcoming.isEmpty) _None(l10n.dashNoUpcoming),
          for (final b in data.upcoming)
            Builder(
              builder: (context) {
                final (icon, color, text) = when(b);
                return InkWell(
                  onTap: onViewAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (icon != null) ...[
                                    Icon(icon, size: 14, color: color),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      '${billTypeLabel(l10n, b.type)} · $text',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          baht(b.amount),
                          style: const TextStyle(
                            color: AppColors.deepNavy,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

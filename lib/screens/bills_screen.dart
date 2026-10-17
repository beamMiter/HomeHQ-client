import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../models/bill.dart';
import '../state/bills_provider.dart';
import '../widgets/item_card.dart';
import '../widgets/add_fab.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/search_bar_field.dart';
import '../widgets/header_row.dart';
import '../widgets/list_empty_state.dart';
import '../widgets/page_loading.dart';
import '../widgets/error_state.dart';
import '../widgets/refresh.dart';
import '../l10n/l10n.dart';
import '../l10n/labels.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});
  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final _q = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _q.text = ref.read(billsQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(billsQueryProvider.notifier).set(v);
    });
  }

  Future<void> _pull() => pullRefresh(() => ref.refresh(billsProvider.future));

  @override
  Widget build(BuildContext context) {
    // sync controller เมื่อ provider เปลี่ยน
    ref.listen<String>(billsQueryProvider, (_, next) {
      if (_q.text != next) _q.text = next;
    });

    final itemsAsync = ref.watch(billsProvider);
    final filter = ref.watch(billsStatusFilterProvider);

    const accent = Color(0xFF1F4E9E);

    final reloading = watchReloading(ref, 'bills');
    final l10n = context.l10n;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        visualDensity: VisualDensity.compact,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: TopNavBar(
          title: 'Bills',
          actions: [
            IconButton(
              tooltip: l10n.billsSummaryTooltip,
              onPressed: () => context.push('/bills/summary'),
              icon: const Icon(Icons.insights),
            ),
            RefreshButton(
              busy: reloading || itemsAsync.isReloadingData,
              onPressed: () => runReload(
                ref,
                'bills',
                () => ref.refresh(billsProvider.future),
              ),
            ),
          ],
        ),
        floatingActionButton: AddFab(
          color: accent,
          tooltip: l10n.billsNew,
          onPressed: () => context.push('/bills/new'),
        ),
        body: ReloadOverlay(
          active: reloading,
          child: Column(
            children: [
              // Header แบบประกอบ: Search ทางซ้าย + Dropdown ทางขวา (เฉพาะ Bills)
              HeaderRow(
                left: SearchBarField(
                  controller: _q,
                  onChanged: _onQueryChanged,
                  onClear: () {
                    _q.clear();
                    ref.read(billsQueryProvider.notifier).clear();
                  },
                  hintText: l10n.billsSearchHint,
                ),
                right: DropdownButtonHideUnderline(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButton<BillsStatusFilter>(
                        value: filter,
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(billsStatusFilterProvider.notifier).set(v);
                          }
                        },
                        items: [
                          DropdownMenuItem(
                            value: BillsStatusFilter.all,
                            child: Text(l10n.commonAll),
                          ),
                          DropdownMenuItem(
                            value: BillsStatusFilter.unpaid,
                            child: Text(l10n.billStatusUnpaid),
                          ),
                          DropdownMenuItem(
                            value: BillsStatusFilter.paid,
                            child: Text(l10n.billStatusPaid),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: itemsAsync.when(
                  loading: () => const PageLoading(),
                  error: (e, _) => RefreshableFill(
                    onRefresh: _pull,
                    child: ErrorState(
                      icon: Icons.error_outline,
                      title: l10n.commonLoadFailed,
                      error: e,
                      onRetry: () => ref.invalidate(billsProvider),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      // Filtered to nothing is not the same as having none.
                      final filtered =
                          _q.text.trim().isNotEmpty ||
                          filter != BillsStatusFilter.all;
                      return RefreshableFill(
                        onRefresh: _pull,
                        child: ListEmptyState(
                          centered: true,
                          icon: filtered
                              ? Icons.search_off_rounded
                              : Icons.receipt_long,
                          title: filtered
                              ? l10n.billsNoMatchTitle
                              : l10n.billsEmptyTitle,
                          subtitle: filtered
                              ? l10n.billsNoMatchHint
                              : l10n.billsEmptyHint,
                          action: Wrap(
                            spacing: 8,
                            children: [
                              if (filtered)
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _q.clear();
                                    ref
                                        .read(billsQueryProvider.notifier)
                                        .clear();
                                    ref
                                        .read(
                                          billsStatusFilterProvider.notifier,
                                        )
                                        .set(BillsStatusFilter.all);
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.billsClearFilters),
                                ),
                              FilledButton.icon(
                                onPressed: () => context.push('/bills/new'),
                                icon: const Icon(Icons.add),
                                label: Text(l10n.billsNew),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator.adaptive(
                      onRefresh: _pull,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _BillCard(
                          bill: items[i],
                          onTap: () => context.push(
                            '/bills/${items[i].id}',
                            extra: items[i],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------- Card UI (สองบรรทัดชิป) -------------------------- */

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, this.onTap});
  final Bill bill;
  final VoidCallback? onTap;

  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFF04438);
  static const _overdue = Color(0xFFB42318);
  static const _soon = Color(0xFFF79009);

  bool get _isPaid => bill.status == 'paid';

  IconData _iconByType(String t) {
    switch (t) {
      case 'electric':
        return Icons.lightbulb_outline;
      case 'water':
        return Icons.water_drop_outlined;
      case 'internet':
        return Icons.wifi_outlined;
      case 'phone':
        return Icons.phone_iphone;
      default:
        return Icons.receipt_long;
    }
  }

  int _daysDiff(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  Color _dueColor(BuildContext ctx, int d) {
    if (_isPaid) return Theme.of(ctx).colorScheme.onSurfaceVariant;
    if (d < 0) return _overdue;
    if (d <= 3) return _soon;
    return Theme.of(ctx).colorScheme.onSurfaceVariant;
  }

  String _dueText(AppLocalizations l10n, DateTime dueDate) {
    final d = _daysDiff(dueDate);
    final fmt = DateFormat('d MMM yyyy');
    if (_isPaid) return l10n.billsPaidOn(fmt.format(dueDate));
    if (d == 0) return l10n.billsDueToday;
    if (d == 1) return l10n.billsDueTomorrow;
    if (d > 1 && d <= 7) return l10n.billsDueInDays(d);
    if (d < 0) return l10n.billsLateDays(-d);
    return l10n.billsDueOn(fmt.format(dueDate));
  }

  Widget _chip(
    BuildContext context, {
    required Widget child,
    Color? fg,
    Color? bg,
    Color? border,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? cs.outlineVariant),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
          color: fg ?? cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿');
    final d = _daysDiff(bill.dueDate);

    final statusFg = _isPaid ? _green : _red;
    final statusBg = statusFg.withValues(alpha: 0.12);

    return ItemCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bill.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                money.format(bill.amount),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chip(
                context,
                fg: statusFg,
                bg: statusBg,
                border: statusFg.withValues(alpha: 0.35),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPaid
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: statusFg,
                    ),
                    const SizedBox(width: 6),
                    Text(_isPaid ? l10n.billStatusPaid : l10n.billStatusUnpaid),
                  ],
                ),
              ),
              _chip(
                context,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconByType(bill.type), size: 14),
                    const SizedBox(width: 6),
                    Text(billTypeLabel(l10n, bill.type)),
                  ],
                ),
              ),
              _chip(
                context,
                fg: _dueColor(context, d),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      d < 0 ? Icons.error_outline : Icons.schedule,
                      size: 14,
                      color: _dueColor(context, d),
                    ),
                    const SizedBox(width: 6),
                    Text(_dueText(l10n, bill.dueDate)),
                  ],
                ),
              ),
            ],
          ),
          if ((bill.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              bill.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/medicine_provider.dart';

import '../widgets/batch_tile.dart';
import '../widgets/qty_badge.dart' as q;
import '../widgets/alert_badge.dart';
import '../widgets/txn_in_sheet.dart';
import '../widgets/alert_sheet.dart';
import '../widgets/error_state.dart';
import '../widgets/list_empty_state.dart';
import '../widgets/page_loading.dart';
import '../widgets/refresh.dart';
import '../l10n/l10n.dart';

class MedicineDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const MedicineDetailScreen({super.key, required this.id});

  @override
  ConsumerState<MedicineDetailScreen> createState() =>
      _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends ConsumerState<MedicineDetailScreen> {
  // Waits for the real request: the old version returned at once, so the pull
  // indicator disappeared before anything had loaded.
  Future<void> _refresh() =>
      pullRefresh(() => ref.refresh(medicineDetailProvider(widget.id).future));

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(medicineDetailProvider(widget.id));
    final dateFmt = DateFormat('d MMM yyyy');

    final reloading = watchReloading(ref, 'medicine:${widget.id}');
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.medDetailTitle),
        actions: [
          RefreshButton(
            busy: reloading || asyncDetail.isReloadingData,
            onPressed: () => runReload(
              ref,
              'medicine:${widget.id}',
              () => ref.refresh(medicineDetailProvider(widget.id).future),
            ),
          ),
        ],
      ),
      body: ReloadOverlay(
        active: reloading,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: asyncDetail.when(
            loading: () => const PageLoading(),
            error: (e, st) => ErrorState(
              title: context.l10n.commonLoadFailed,
              error: e,
              onRetry: _refresh,
            ),
            data: (d) {
              final batches = d.batches;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // การ์ดข้อมูลยา
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE7ECF4),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.item.name,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    q.qtyBadge(
                                      context,
                                      d.item.stockQty.toInt(),
                                      low: (d.alert?.minQty ?? 10).toInt(),
                                    ),
                                    const SizedBox(width: 8),
                                    AlertBadge(alert: d.alert),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (d.nextExpiry != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.event, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        context.l10n.medDetailExpiringSoon(
                                          dateFmt.format(d.nextExpiry!),
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          Text(
                            context.l10n.medDetailLots,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (batches.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListEmptyState(
                          // ❌ เอา const ออก
                          title: context.l10n.medDetailNoLots,
                          subtitle: context.l10n.medDetailNoLotsHint,
                        ),
                      ),
                    )
                  else
                    SliverList.separated(
                      itemCount: batches.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: BatchTile(b: batches[i]),
                      ),
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                    ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.medDetailAlerts,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          AlertBadge(alert: d.alert, dense: false),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _ActionBar(
        onOut: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                AlertSheet(id: widget.id), // ถ้าจะเบิกยา ใช้ TxnOutSheet
          );
        },
        onIn: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => TxnInSheet(id: widget.id),
          );
        },
        onAlert: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AlertSheet(id: widget.id),
          );
        },
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onOut;
  final VoidCallback onIn;
  final VoidCallback onAlert;

  const _ActionBar({
    required this.onOut,
    required this.onIn,
    required this.onAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.only(
        top: 8,
        left: 12,
        right: 12,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onOut,
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(context.l10n.medTxnOutTitle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onIn,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(context.l10n.medTxnInTitle),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onAlert,
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: context.l10n.medAlertTitle,
          ),
        ],
      ),
    );
  }
}

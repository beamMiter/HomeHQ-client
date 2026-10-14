import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../repositories/purchase_repository.dart';
import '../state/auth_state.dart';
import '../state/purchase_providers.dart';
import '../state/purchase_actions.dart';
import '../models/purchase_model.dart';
import '../widgets/detail_bottom_bar.dart';
import '../widgets/error_state.dart';
import '../widgets/more_menu.dart';
import '../widgets/page_loading.dart';
import '../widgets/toast.dart';
import '../widgets/refresh.dart';
import '../l10n/friendly_error.dart';
import '../l10n/l10n.dart';
import '../utils/numbers.dart';

class PurchaseDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const PurchaseDetailScreen({super.key, required this.id});

  @override
  ConsumerState<PurchaseDetailScreen> createState() =>
      _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  bool _busy = false;

  String get id => widget.id;

  /// Runs one change to the purchase and says how it went.
  Future<void> _change(
    Future<Purchase> Function(PurchaseRepository repo) act, {
    required String done,
  }) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await act(ref.read(purchaseRepoProvider));
      ref.invalidate(purchaseDetailProvider(id));
      ref.invalidate(purchasesListProvider);
      AppToast.success(done);
    } catch (e) {
      AppToast.error(friendlyError(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    final l10n = context.l10n;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final filename = result.files.single.name;

      AppToast.info(l10n.purchUploading);
      await ref.read(
        uploadAttachmentProvider(
          UploadAttachmentPayload(id: id, file: file, filename: filename),
        ).future,
      );
      AppToast.success(l10n.purchUploadDone);
    } catch (e) {
      AppToast.error(l10n.purchUploadFailed(friendlyError(l10n, e)));
    }
  }

  Future<double?> _askAmountPaid(Purchase p) {
    final l10n = context.l10n;
    final controller = TextEditingController(
      text: p.amountEstimated == null
          ? ''
          : p.amountEstimated!.toStringAsFixed(
              p.amountEstimated! % 1 == 0 ? 0 : 2,
            ),
    );
    String? error;
    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.purchPaidTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.purchPaidLabel,
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v == null || v < 0) {
                  setLocal(() => error = l10n.purchPaidInvalid);
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelPurchase() async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.purchCancelAsk),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.purchCancelKeep),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.purchCancelPurchase),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _change((r) => r.cancel(id), done: l10n.purchCancelled);
  }

  /// The one thing to do next, if there is one for this person.
  DetailAction? _primary(Purchase p, String? me) {
    final l10n = context.l10n;
    final mine = me != null && p.buyerId == me;
    switch (p.status) {
      case PurchaseStatus.planned:
        if ((p.buyerId ?? '').isNotEmpty) return null;
        return DetailAction(
          label: l10n.purchTake,
          icon: Icons.shopping_bag_outlined,
          busy: _busy,
          onPressed: () =>
              _change((r) => r.claim(id), done: l10n.purchStatusUpdated),
        );
      case PurchaseStatus.ordered:
        if (!mine) return null;
        return DetailAction(
          label: l10n.purchMarkBought,
          icon: Icons.shopping_cart_checkout_rounded,
          busy: _busy,
          onPressed: () async {
            final paid = await _askAmountPaid(p);
            if (paid == null) return;
            await _change(
              (r) => r.markBought(id, amountPaid: paid),
              done: l10n.purchStatusUpdated,
            );
          },
        );
      case PurchaseStatus.bought:
        if (!mine) return null;
        return DetailAction(
          label: l10n.purchMarkDelivered,
          icon: Icons.inventory_2_outlined,
          busy: _busy,
          onPressed: () => _change(
            (r) => r.markDelivered(id),
            done: l10n.purchStatusUpdated,
          ),
        );
      case PurchaseStatus.delivered:
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return null;
    }
  }

  /// "⋯": everything that is not the next step.
  List<MoreMenuItem> _menu(Purchase p, String? me) {
    final l10n = context.l10n;
    final involved = me != null && (p.requesterId == me || p.buyerId == me);
    final open =
        p.status == PurchaseStatus.planned ||
        p.status == PurchaseStatus.ordered;
    return [
      if (me != null && p.requesterId == me)
        MoreMenuItem(
          label: l10n.commonEdit,
          icon: Icons.edit_outlined,
          onSelected: () => context.push('/purchases/$id/edit'),
        ),
      if (involved)
        MoreMenuItem(
          label: l10n.purchAttach,
          icon: Icons.attach_file_rounded,
          onSelected: _attach,
        ),
      if (involved && open)
        MoreMenuItem(
          label: l10n.purchCancelPurchase,
          icon: Icons.cancel_outlined,
          destructive: true,
          onSelected: _cancelPurchase,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(purchaseDetailProvider(id));
    final me = ref.watch(authProvider.select((s) => s.user?.id));
    final p = asyncDetail.value;

    final reloading = watchReloading(ref, 'purchase:$id');
    final primary = p == null ? null : _primary(p, me);
    final menu = p == null ? const <MoreMenuItem>[] : _menu(p, me);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.purchDetailTitle),
        actions: [
          RefreshButton(
            busy: reloading || asyncDetail.isReloadingData,
            onPressed: () => runReload(
              ref,
              'purchase:$id',
              () => ref.refresh(purchaseDetailProvider(id).future),
            ),
          ),
          MoreMenuButton(items: menu),
        ],
      ),
      body: ReloadOverlay(
        active: reloading,
        child: asyncDetail.when(
          loading: () => const PageLoading(),
          error: (e, _) => ErrorState(
            title: context.l10n.purchDetailLoadFailed(
              friendlyError(context.l10n, e),
            ),
            icon: Icons.error_outline,
            retryLabel: context.l10n.commonTryAgain,
            onRetry: () => ref.invalidate(purchaseDetailProvider(id)),
          ),
          data: (p) => RefreshIndicator(
            onRefresh: () => pullRefresh(
              () => ref.refresh(purchaseDetailProvider(id).future),
            ),
            child: _DetailView(p: p),
          ),
        ),
      ),
      bottomNavigationBar: primary == null
          ? null
          : DetailBottomBar(primary: primary),
    );
  }
}

class _DetailView extends StatelessWidget {
  final Purchase p;
  const _DetailView({required this.p});

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.currency(
      locale: 'th_TH',
      symbol: (p.currency == null || p.currency!.isEmpty) ? '฿' : p.currency!,
      decimalDigits: 2,
    );

    final items = p.items;
    final lineTotal = items.fold<double>(
      0,
      (sum, it) => sum + ((it.price ?? 0.0) * ((it.qty ?? 0).toDouble())),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(p: p, nf: nf),
        const SizedBox(height: 12),
        if (p.note?.isNotEmpty == true) ...[
          _SectionCard(
            title: context.l10n.commonNote,
            child: Text(p.note!, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 12),
        ],
        _SectionCard(
          title: context.l10n.purchItemsTitle,
          trailing: Text(
            context.l10n.purchItemsCount(items.length),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          child: items.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    context.l10n.purchNoItems,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    ...items.map(
                      (it) => _LineItemTile(
                        name: it.name,
                        unit: it.unit,
                        qty: it.qty,
                        price: it.price,
                        currencySymbol:
                            (p.currency == null || p.currency!.isEmpty)
                            ? '฿'
                            : p.currency!,
                        nf: nf,
                      ),
                    ),
                    const Divider(height: 24),
                    // Only when the items carry prices: otherwise "0.00" reads
                    // as if the items cost nothing.
                    if (lineTotal > 0)
                      _KeyValueRow(
                        label: context.l10n.purchTotalByItems,
                        value: nf.format(lineTotal),
                        isEmphasis: true,
                      ),
                    if (p.amountEstimated != null) ...[
                      const SizedBox(height: 6),
                      _KeyValueRow(
                        label: context.l10n.purchEstimated,
                        value: nf.format(p.amountEstimated),
                      ),
                    ],
                    if (p.amountPaid != null) ...[
                      const SizedBox(height: 6),
                      _KeyValueRow(
                        label: context.l10n.purchPaid,
                        value: nf.format(p.amountPaid),
                      ),
                    ],
                  ],
                ),
        ),
        _SectionCard(
          title: context.l10n.purchAttachments,
          child: _AttachmentsGrid(
            purchaseId: p.id,
            attachments: p.attachments ?? [],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Purchase p;
  final NumberFormat nf;
  const _SummaryCard({required this.p, required this.nf});

  Color _statusBg(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    switch (p.status) {
      case PurchaseStatus.planned:
        return cs.surfaceContainerHighest;
      case PurchaseStatus.ordered:
        return Colors.blue.withValues(alpha: .15);
      case PurchaseStatus.bought:
        return Colors.amber.withValues(alpha: .2);
      case PurchaseStatus.delivered:
        return Colors.green.withValues(alpha: .2);
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return Colors.red.withValues(alpha: .2);
    }
  }

  Color _statusFg(BuildContext ctx) {
    switch (p.status) {
      case PurchaseStatus.planned:
        return Theme.of(ctx).colorScheme.onSurfaceVariant;
      case PurchaseStatus.ordered:
        return Colors.blue.shade700;
      case PurchaseStatus.bought:
        return Colors.orange.shade800;
      case PurchaseStatus.delivered:
        return Colors.green.shade800;
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return Colors.red.shade700;
    }
  }

  String _statusLabel(BuildContext context) {
    switch (p.status) {
      case PurchaseStatus.planned:
        return context.l10n.purchStatusPlanned;
      case PurchaseStatus.ordered:
        return context.l10n.purchStatusOrdered;
      case PurchaseStatus.bought:
        return context.l10n.purchStatusBought;
      case PurchaseStatus.delivered:
        return context.l10n.purchStatusDelivered;
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return context.l10n.purchStatusCanceled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(context),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _statusFg(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (p.category?.isNotEmpty == true)
                  _InfoChip(icon: Icons.folder, label: p.category!),
                if (p.store?.isNotEmpty == true)
                  _InfoChip(icon: Icons.store_mall_directory, label: p.store!),
                if (p.amountEstimated != null)
                  _InfoChip(
                    icon: Icons.calculate_outlined,
                    label: context.l10n.purchEstimatedAmount(
                      nf.format(p.amountEstimated),
                    ),
                  ),
                if (p.amountPaid != null)
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: context.l10n.purchPaidAmount(
                      nf.format(p.amountPaid),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _LineItemTile extends StatelessWidget {
  final String name;
  final String? unit;
  final num? qty;
  final double? price;
  final String currencySymbol;
  final NumberFormat nf;

  const _LineItemTile({
    required this.name,
    required this.unit,
    required this.qty,
    required this.price,
    required this.currencySymbol,
    required this.nf,
  });

  @override
  Widget build(BuildContext context) {
    final q = (qty ?? 0);
    final subtitle = [
      context.l10n.purchItemQty(qty == null ? "-" : qtyText(q)),
      if ((unit ?? '').isNotEmpty) unit!,
      if (price != null) context.l10n.purchItemPrice(nf.format(price)),
    ].join(' ');

    final lineSum = price == null ? null : (price! * q.toDouble());

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: lineSum == null
          ? null
          : Text(
              nf.format(lineSum),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmphasis;
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: t.bodyMedium)),
        Text(
          value,
          style: (isEmphasis ? t.titleMedium : t.bodyMedium)?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _AttachmentsGrid extends ConsumerWidget {
  final String purchaseId;
  final List<FileAttachment> attachments;
  const _AttachmentsGrid({required this.purchaseId, required this.attachments});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachments.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          context.l10n.purchNoAttachments,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: attachments.map((att) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(
              att.fileName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: att.bytes != null
                ? Text('${(att.bytes! / 1024).toStringAsFixed(1)} KB')
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: context.l10n.purchOpen,
                  onPressed: () async {
                    final uri = Uri.parse(att.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (!context.mounted) return;
                      AppToast.error(context.l10n.purchCantOpenLink);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: context.l10n.purchDeleteAttachment,
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.l10n.purchDeleteAttachmentAsk),
                        content: Text(
                          context.l10n.purchDeleteAttachmentBody(att.fileName),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(context.l10n.commonCancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              context.l10n.commonDelete,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        if (!context.mounted) return;
                        AppToast.info(context.l10n.purchDeleting);
                        await ref.read(
                          deleteAttachmentProvider(
                            DeleteAttachmentPayload(
                              id: purchaseId,
                              fileId: att.id,
                            ),
                          ).future,
                        );
                        if (!context.mounted) return;
                        AppToast.success(context.l10n.purchDeleted);
                      } catch (e) {
                        if (!context.mounted) return;
                        AppToast.error(
                          context.l10n.purchDeleteFailed(
                            friendlyError(context.l10n, e),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

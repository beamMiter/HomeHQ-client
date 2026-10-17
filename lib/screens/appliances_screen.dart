import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../models/appliance.dart';
import '../shared/app_colors.dart';
import '../state/appliances_provider.dart';
import '../state/auth_state.dart';
import '../widgets/add_fab.dart';
import '../widgets/appliances/appliance_status.dart';
import '../widgets/appliances/appliance_text.dart';
import '../widgets/error_state.dart';
import '../widgets/list_empty_state.dart';
import '../widgets/page_loading.dart';
import '../widgets/refresh.dart';
import '../widgets/toast.dart';
import '../widgets/top_nav_bar.dart';

/// Home Appliances: what can be switched in the house, grouped by room, with
/// its status and a power switch on each. How many are on, off and offline
/// sits on top (tap one to see only those), and the list is checked
/// again every few seconds while it is open. Tapping one opens its page.
///
/// The vendor account stays on the server; this screen only shows what the
/// server lists and sends the server commands.
class AppliancesScreen extends ConsumerWidget {
  const AppliancesScreen({super.key});

  static const _key = 'appliances';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(appliancesStatusProvider);
    final reloading = watchReloading(ref, _key);
    final isAdmin = ref.watch(
      authProvider.select((s) => s.user?.isAdmin ?? false),
    );
    // The household can add its own appliances, and this person may.
    final canAdd = status.value?.canAdd == true && isAdmin;

    Future<void> reload() async {
      final s = await ref.refresh(appliancesStatusProvider.future);
      // Left meanwhile: nothing more to show.
      if (!context.mounted) return;
      if (s?.enabled == true) {
        await ref.read(appliancesProvider.notifier).reload();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgSoft,
      floatingActionButton: canAdd
          ? AddFab(
              tooltip: l10n.applAddButton,
              color: AppColors.softBlue,
              onPressed: () => context.push('/appliances/new'),
            )
          : null,
      appBar: TopNavBar(
        // A feature name: not translated (see the home screen).
        title: 'Home Appliances',
        onBack: () => applianceBack(context),
        actions: [
          RefreshButton(
            busy: reloading,
            onPressed: () => runReload(ref, _key, reload),
          ),
        ],
      ),
      body: ReloadOverlay(
        active: reloading,
        child: status.when(
          loading: () => const PageLoading(),
          error: (e, _) => RefreshableFill(
            onRefresh: () => pullRefresh(reload),
            child: ErrorState(
              icon: Icons.error_outline,
              title: l10n.applLoadFailed,
              onRetry: () => ref.invalidate(appliancesStatusProvider),
            ),
          ),
          data: (s) {
            if (s == null) {
              return RefreshableFill(
                onRefresh: () => pullRefresh(reload),
                child: ErrorState(
                  icon: Icons.cloud_off,
                  title: l10n.applLoadFailed,
                  onRetry: () => ref.invalidate(appliancesStatusProvider),
                ),
              );
            }
            if (!s.enabled) {
              return RefreshableFill(
                onRefresh: () => pullRefresh(reload),
                child: ListEmptyState(
                  centered: true,
                  icon: Icons.power_off_outlined,
                  title: l10n.applDisabledTitle,
                  subtitle: l10n.applDisabledHint,
                ),
              );
            }
            return _ApplianceList(
              onRefresh: () => pullRefresh(reload),
              canAdd: canAdd,
            );
          },
        ),
      ),
    );
  }
}

class _ApplianceList extends ConsumerStatefulWidget {
  const _ApplianceList({required this.onRefresh, required this.canAdd});
  final Future<void> Function() onRefresh;
  final bool canAdd;

  @override
  ConsumerState<_ApplianceList> createState() => _ApplianceListState();
}

class _ApplianceListState extends ConsumerState<_ApplianceList> {
  /// Only appliances with this status are shown, or all of them.
  ApplianceStatus? _only;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = ref.watch(appliancesProvider);
    final onRefresh = widget.onRefresh;
    final canAdd = widget.canAdd;

    return items.when(
      loading: () => const PageLoading(),
      error: (e, _) => RefreshableFill(
        onRefresh: onRefresh,
        child: ErrorState(
          icon: Icons.error_outline,
          title: l10n.applLoadFailed,
          error: applianceErrorText(l10n, e),
          onRetry: () => ref.invalidate(appliancesProvider),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return RefreshableFill(
            onRefresh: onRefresh,
            child: ListEmptyState(
              centered: true,
              icon: Icons.devices_other_outlined,
              title: l10n.applEmptyTitle,
              subtitle: l10n.applEmptyHint,
              action: canAdd
                  ? FilledButton.icon(
                      onPressed: () => context.push('/appliances/new'),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.applAddFirst),
                    )
                  : null,
            ),
          );
        }

        // Rooms in the order the server lists them; no room goes last.
        final only = _only;
        final shown = only == null
            ? list
            : list.where((a) => a.status == only).toList();
        final rooms = <String?, List<Appliance>>{};
        for (final a in shown) {
          rooms.putIfAbsent(a.room, () => []).add(a);
        }
        final keys = [
          ...rooms.keys.whereType<String>(),
          if (rooms.containsKey(null)) null,
        ];

        return ApplianceLiveUpdates(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                ApplianceStatusOverview(
                  items: list,
                  selected: only,
                  onSelect: (s) => setState(() => _only = s),
                ),
                if (only != null && shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      l10n.applStatusFilterNone(
                        StatusLook.forStatus(l10n, only).label.toLowerCase(),
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                for (final room in keys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                    child: Text(
                      room ?? l10n.applNoRoom,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  for (final a in rooms[room]!) ...[
                    _ApplianceCard(appliance: a),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApplianceCard extends ConsumerStatefulWidget {
  const _ApplianceCard({required this.appliance});
  final Appliance appliance;

  @override
  ConsumerState<_ApplianceCard> createState() => _ApplianceCardState();
}

class _ApplianceCardState extends ConsumerState<_ApplianceCard> {
  /// A power command is in flight: not flippable again until it lands.
  bool _sending = false;

  Future<void> _toggle(bool on) async {
    final l10n = context.l10n;
    final a = widget.appliance;
    setState(() => _sending = true);
    try {
      await ref
          .read(appliancesProvider.notifier)
          .command(a.id, Appliance.power, on);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(applianceCommandError(l10n, a.name, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = widget.appliance;
    final look = StatusLook.of(l10n, a);
    final offline = a.status == ApplianceStatus.offline;
    final lit = a.status == ApplianceStatus.on || a.switchingTo != null;
    final canSwitch =
        a.online && a.hasPower && !_sending && a.switchingTo == null;
    final now = ref.watch(appliancesClockProvider)();
    // Since when, or when it switches itself off, then what it is set to.
    final detail = [
      ?applianceStatusDetail(context, a, now),
      ...applianceSettings(l10n, a),
    ].join(' · ');

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Offline ones open too: their page says what was last known.
        onTap: () =>
            context.push('/appliances/${Uri.encodeComponent(a.id)}', extra: a),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              // The kind, lit while it runs, and a dot in its status colour.
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lit
                            ? AppColors.softBlue.withValues(alpha: .12)
                            : const Color(0xFFF1F4F9),
                      ),
                      // The app's colour for "on"; the status colour is the
                      // dot's (a green flame would read oddly).
                      child: Icon(
                        applianceIcon(a.kind),
                        color: lit ? AppColors.softBlue : AppColors.textMuted,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: look.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  // Can't be reached: a little faded, as it may not be so.
                  opacity: offline ? 0.75 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepNavy,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(child: ApplianceStatusBadge(appliance: a)),
                          if (detail.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (a.online && a.hasPower)
                Switch.adaptive(
                  value: a.isOn,
                  activeThumbColor: AppColors.softBlue,
                  onChanged: canSwitch ? _toggle : null,
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

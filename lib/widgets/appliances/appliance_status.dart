import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/appliance.dart';
import '../../shared/app_colors.dart';
import '../../state/appliances_provider.dart';

/// The status colours. They mean status and nothing else, and they never
/// stand alone: every use comes with its icon and its words.
abstract final class StatusColors {
  static const on = Color(0xFF0CA30C);
  static const off = Color(0xFF64748B);
  static const offline = Color(0xFFD03B3B);
  static const warning = Color(0xFFD48806);
  static const pending = AppColors.softBlue;
}

/// How a status looks: its colour, its icon and its words.
class StatusLook {
  const StatusLook(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;

  static StatusLook forStatus(AppLocalizations l10n, ApplianceStatus s) =>
      switch (s) {
        ApplianceStatus.on => StatusLook(
          StatusColors.on,
          Icons.check_circle_rounded,
          l10n.applStatusOn,
        ),
        ApplianceStatus.off => StatusLook(
          StatusColors.off,
          Icons.radio_button_unchecked_rounded,
          l10n.applStatusOff,
        ),
        ApplianceStatus.offline => StatusLook(
          StatusColors.offline,
          Icons.cloud_off_rounded,
          l10n.applOffline,
        ),
      };

  /// One appliance's: turning on or off while a power command is on its way,
  /// and
  /// marked when the appliance didn't confirm the last one.
  static StatusLook of(AppLocalizations l10n, Appliance a) {
    final to = a.switchingTo;
    if (to != null) {
      return StatusLook(
        StatusColors.pending,
        Icons.sync_rounded,
        to ? l10n.applStatusTurningOn : l10n.applStatusTurningOff,
      );
    }
    final look = forStatus(l10n, a.status);
    if (a.unconfirmed && a.status != ApplianceStatus.offline) {
      return StatusLook(
        StatusColors.warning,
        Icons.help_outline_rounded,
        '${look.label} · ${l10n.applStatusUnconfirmed}',
      );
    }
    return look;
  }
}

/// An appliance's status as a pill: icon and words on a tint of its colour.
class ApplianceStatusBadge extends StatelessWidget {
  const ApplianceStatusBadge({
    super.key,
    required this.appliance,
    this.large = false,
  });

  final Appliance appliance;
  final bool large;

  @override
  Widget build(BuildContext context) =>
      StatusPill(look: StatusLook.of(context.l10n, appliance), large: large);
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.look, this.large = false});

  final StatusLook look;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 8,
        vertical: large ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: look.color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: look.color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(look.icon, size: large ? 16 : 13, color: look.color),
          SizedBox(width: large ? 6 : 4),
          Flexible(
            child: Text(
              look.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.deepNavy,
                fontWeight: FontWeight.w700,
                fontSize: large ? 13 : 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How long something has been, in the largest units that read well:
/// "under a minute", "12 min", "2 h 5 min", "3 d 4 h".
String applianceDuration(AppLocalizations l10n, Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inMinutes < 1) return l10n.applDurUnderMinute;
  if (d.inHours < 1) return l10n.applDurMinutes(d.inMinutes);
  if (d.inDays < 1) {
    final m = d.inMinutes % 60;
    return m == 0
        ? l10n.applDurHoursOnly(d.inHours)
        : l10n.applDurHours(d.inHours, m);
  }
  return l10n.applDurDays(d.inDays, d.inHours % 24);
}

/// A time of day, with the date when it isn't today.
String applianceClock(BuildContext context, DateTime at, DateTime now) {
  final locale = Localizations.localeOf(context).toString();
  final t = at.toLocal(), n = now.toLocal();
  final today = t.year == n.year && t.month == n.month && t.day == n.day;
  return DateFormat(today ? 'HH:mm' : 'd MMM HH:mm', locale).format(t);
}

/// "Checked just now" / "Checked 40 s ago": when the app last heard from the
/// server. Within one round of checks it counts as just now.
String applianceChecked(AppLocalizations l10n, DateTime at, DateTime now) {
  final ago = now.difference(at);
  if (ago < const Duration(seconds: 15)) return l10n.applCheckedJustNow;
  if (ago < const Duration(minutes: 1)) {
    return l10n.applCheckedAgo(l10n.applDurSeconds(ago.inSeconds));
  }
  return l10n.applCheckedAgo(applianceDuration(l10n, ago));
}

/// The status of one appliance, in full: what it is and since when, when it
/// will switch itself off, whether the last command was confirmed, and when
/// the app last checked, with a button to check now.
class ApplianceStatusPanel extends ConsumerWidget {
  const ApplianceStatusPanel({
    super.key,
    required this.appliance,
    required this.onCheck,
    required this.checking,
  });

  final Appliance appliance;
  final VoidCallback onCheck;
  final bool checking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final a = appliance;
    final now = ref.watch(appliancesClockProvider)();
    final sync = ref.watch(applianceSyncProvider);
    String clock(DateTime t) => applianceClock(context, t, now);

    final lines = <Widget>[];
    void line(IconData icon, String text, {Color? color}) => lines.add(
      _Line(icon: icon, text: text, color: color ?? AppColors.textMuted),
    );

    // On or off is what the power button and the drawing already say, so the
    // pill only comes when there is something they don't: it can't be
    // reached, a command is on its way, or the last one is unconfirmed.
    final pill =
        a.status == ApplianceStatus.offline ||
        a.switchingTo != null ||
        a.unconfirmed;

    final since = a.since;
    if (a.status == ApplianceStatus.offline) {
      line(
        Icons.cloud_off_rounded,
        l10n.applStatusOfflineBody(a.isOn ? l10n.applOn : l10n.applOff),
        color: StatusColors.offline,
      );
    } else if (since != null && a.switchingTo == null) {
      final d = applianceDuration(l10n, now.difference(since));
      line(
        Icons.schedule_rounded,
        a.isOn
            ? l10n.applStatusOnSince(clock(since), d)
            : l10n.applStatusOffSince(clock(since), d),
      );
    }
    final off = a.autoOffAt;
    if (off != null && a.isOn && a.status != ApplianceStatus.offline) {
      line(
        Icons.shield_outlined,
        l10n.applStatusAutoOff(
          clock(off),
          applianceDuration(l10n, off.difference(now)),
        ),
      );
    }
    if (a.unconfirmed) {
      line(
        Icons.help_outline_rounded,
        l10n.applStatusUnconfirmedBody,
        color: StatusColors.warning,
      );
    }
    // When it was last checked: beside the button when there is no pill,
    // else the last of the lines.
    final checked = sync.checkedAt;
    final checkedLine = checked == null
        ? null
        : sync.failing
        ? _Line(
            icon: Icons.warning_amber_rounded,
            text: l10n.applCheckFailed(clock(checked)),
            color: StatusColors.warning,
            top: pill ? 6 : 0,
          )
        : _Line(
            icon: Icons.update_rounded,
            text: applianceChecked(l10n, checked, now),
            color: AppColors.textMuted,
            top: pill ? 6 : 0,
          );
    if (pill && checkedLine != null) lines.add(checkedLine);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (pill)
              Flexible(child: ApplianceStatusBadge(appliance: a, large: true))
            else
              Expanded(child: checkedLine ?? const SizedBox.shrink()),
            TextButton.icon(
              onPressed: checking ? null : onCheck,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.applCheckNow),
            ),
          ],
        ),
        if (lines.isNotEmpty) ...[const SizedBox(height: 6), ...lines],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.text,
    required this.color,
    this.top = 6,
  });

  final IconData icon;
  final String text;
  final Color color;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textMain, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a card says next to the status: since when it has been on or off,
/// when a heater switches itself off, or what was last known of one that
/// can't be reached. Null when there is nothing worth saying.
String? applianceStatusDetail(BuildContext context, Appliance a, DateTime now) {
  final l10n = context.l10n;
  if (a.switchingTo != null) return null;
  if (a.status == ApplianceStatus.offline) {
    return l10n.applLastKnown(a.isOn ? l10n.applOn : l10n.applOff);
  }
  final off = a.autoOffAt;
  if (off != null && a.isOn) {
    return l10n.applAutoOffShort(applianceDuration(l10n, off.difference(now)));
  }
  final since = a.since;
  if (since != null) {
    return l10n.applSinceShort(applianceClock(context, since, now));
  }
  return null;
}

/// The page's status at a glance: how many are on, the share of on, off and
/// offline as one bar, a tile per status that shows only those when tapped,
/// a warning when something can't be reached, and when the list was last
/// checked.
class ApplianceStatusOverview extends ConsumerWidget {
  const ApplianceStatusOverview({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<Appliance> items;

  /// The status shown alone, or null for all of them.
  final ApplianceStatus? selected;
  final ValueChanged<ApplianceStatus?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(appliancesClockProvider)();
    final sync = ref.watch(applianceSyncProvider);
    int count(ApplianceStatus s) => items.where((a) => a.status == s).length;
    final on = count(ApplianceStatus.on);
    final off = count(ApplianceStatus.off);
    final offline = count(ApplianceStatus.offline);
    final checked = sync.checkedAt;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.applStatusSummaryLabel(on, off, offline),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    l10n.applHomeOn(on, items.length),
                    style: const TextStyle(
                      color: AppColors.deepNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (checked != null && !sync.failing) ...[
                  const Icon(
                    Icons.update_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    applianceChecked(l10n, checked, now),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _ShareBar(on: on, off: off, offline: offline),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (key, status, n) in [
                  ('all', null, items.length),
                  ('on', ApplianceStatus.on, on),
                  ('off', ApplianceStatus.off, off),
                  ('offline', ApplianceStatus.offline, offline),
                ]) ...[
                  if (key != 'all') const SizedBox(width: 8),
                  Expanded(
                    child: _StatusTile(
                      key: ValueKey('status-$key'),
                      countKey: ValueKey('status-$key-count'),
                      look: status == null
                          ? StatusLook(
                              AppColors.deepNavy,
                              Icons.apps_rounded,
                              l10n.applStatusAll,
                            )
                          : StatusLook.forStatus(l10n, status),
                      count: n,
                      selected: selected == status,
                      onTap: status != null && n == 0 && selected != status
                          ? null
                          : () => onSelect(
                              status == null || selected == status
                                  ? null
                                  : status,
                            ),
                    ),
                  ),
                ],
              ],
            ),
            if (offline > 0 && selected != ApplianceStatus.offline) ...[
              const SizedBox(height: 10),
              _Note(
                icon: Icons.cloud_off_rounded,
                color: StatusColors.offline,
                text: l10n.applOfflineAlert(offline),
                onTap: () => onSelect(ApplianceStatus.offline),
              ),
            ],
            if (sync.failing && checked != null) ...[
              const SizedBox(height: 10),
              _Note(
                icon: Icons.warning_amber_rounded,
                color: StatusColors.warning,
                text: l10n.applCheckFailed(
                  applianceClock(context, checked, now),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// On, off and offline as shares of one bar, in that order, with a 2 px gap
/// between them. The counts are in the tiles below; this is the proportion.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.on, required this.off, required this.offline});

  final int on, off, offline;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (on, StatusColors.on),
      (off, const Color(0xFFCBD3DE)),
      (offline, StatusColors.offline),
    ].where((p) => p.$1 > 0).toList();
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: parts.isEmpty
              ? const ColoredBox(color: Color(0xFFEDF0F6))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < parts.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: parts[i].$1,
                        child: ColoredBox(color: parts[i].$2),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// One status as a tile: its number, large, over its icon and name. Tapped,
/// it shows only those.
class _StatusTile extends StatelessWidget {
  const _StatusTile({
    super.key,
    required this.countKey,
    required this.look,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final Key countKey;
  final StatusLook look;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dim = onTap == null;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? look.color.withValues(alpha: .10)
            : const Color(0xFFF6F8FB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected
                ? look.color.withValues(alpha: .55)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Opacity(
            opacity: dim ? 0.45 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
              child: Column(
                children: [
                  Text(
                    '$count',
                    key: countKey,
                    style: const TextStyle(
                      color: AppColors.deepNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(look.icon, size: 12, color: look.color),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          look.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.color,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 13,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps the appliances fresh while [child] is on screen: checks them again
/// every [every] while the app is in front, and at once when it comes back.
/// Someone else may switch something, or the server's safety switch-off may
/// fire; without this the screen would go on showing what was.
class ApplianceLiveUpdates extends ConsumerStatefulWidget {
  const ApplianceLiveUpdates({
    super.key,
    required this.child,
    this.every = const Duration(seconds: 10),
  });

  final Widget child;
  final Duration every;

  @override
  ConsumerState<ApplianceLiveUpdates> createState() =>
      _ApplianceLiveUpdatesState();
}

class _ApplianceLiveUpdatesState extends ConsumerState<ApplianceLiveUpdates>
    with WidgetsBindingObserver {
  Timer? _timer;

  /// Taken while this is in the tree, so a timer or a lifecycle change never
  /// has to look anything up through the widget tree: by then this may be on
  /// its way out of it, where a lookup is an error.
  late ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.every, (_) => _check());
  }

  void _check() {
    if (!mounted) return;
    _container.read(appliancesProvider.notifier).check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _check();
        _start();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

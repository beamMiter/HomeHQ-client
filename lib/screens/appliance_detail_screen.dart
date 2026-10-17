import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/appliance.dart';
import '../shared/app_colors.dart';
import '../state/appliances_provider.dart';
import '../state/auth_state.dart';
import '../widgets/appliances/aircon_hero.dart';
import '../widgets/appliances/appliance_status.dart';
import '../widgets/appliances/appliance_text.dart';
import '../widgets/appliances/cooler_hero.dart';
import '../widgets/appliances/heater_hero.dart';
import '../widgets/appliances/light_hero.dart';
import '../widgets/list_empty_state.dart';
import '../widgets/page_loading.dart';
import '../widgets/toast.dart';
import '../widgets/top_nav_bar.dart';

/// One appliance: its drawing (for the kinds that have one), its status in
/// full, power, every other control it reports, and who sent it what lately.
/// While the page is open the status is checked again every few seconds.
///
/// Everybody may switch power. The other controls are for admins; a member
/// sees them, locked, so they know they exist.
class ApplianceDetailScreen extends ConsumerStatefulWidget {
  const ApplianceDetailScreen({super.key, required this.id, this.appliance});

  final String id;

  /// What the list already knew, shown until the list reloads.
  final Appliance? appliance;

  @override
  ConsumerState<ApplianceDetailScreen> createState() =>
      _ApplianceDetailScreenState();
}

class _ApplianceDetailScreenState extends ConsumerState<ApplianceDetailScreen> {
  /// Capabilities with a command in flight: not changeable again until it lands.
  final Set<String> _sending = {};

  /// Where a slider is being dragged to, before it is sent.
  final Map<String, double> _drag = {};

  /// "Check now" is running.
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    try {
      await ref.read(appliancesProvider.notifier).reload();
    } catch (_) {
      // The status card says the check failed and what is shown instead.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// The drawing for kinds that have one, or null.
  Widget? _hero(Appliance a) {
    if (!a.hasPower) return null;
    final on = a.online && a.isOn;
    final enabled = a.online && !_sending.contains(Appliance.power);
    void power(bool v) => _send(a, Appliance.power, v);
    final mode = a.state['mode'] is String ? a.state['mode'] as String : null;
    return switch (a.kind) {
      'aircon' => AirconHero(
        on: on,
        mode: mode ?? 'cool',
        temperature: a.intValue('temperature') ?? 25,
        fanSpeed: a.intValue('fan_speed') ?? 2,
        swing: a.state[Appliance.swing] == true,
        enabled: enabled,
        onPower: power,
        offline: !a.online,
      ),
      'light' => LightHero(
        on: on,
        // Follows the slider while it is dragged.
        brightness:
            (_drag['brightness']?.round() ?? a.intValue('brightness') ?? 100),
        enabled: enabled,
        onPower: power,
        offline: !a.online,
      ),
      'cooler' => CoolerHero(
        on: on,
        speed: a.intValue('fan_speed') ?? 2,
        swing: a.state[Appliance.swing] == true,
        cooling: a.state['cooling'] == true,
        mode: mode ?? 'normal',
        enabled: enabled,
        onPower: power,
        offline: !a.online,
      ),
      'heater' => HeaterHero(
        on: on,
        since: a.since,
        autoOffAt: a.autoOffAt,
        enabled: enabled,
        onPower: power,
        offline: !a.online,
        clock: ref.read(appliancesClockProvider),
      ),
      _ => null,
    };
  }

  Future<void> _send(Appliance a, String key, Object value) async {
    final l10n = context.l10n;
    setState(() => _sending.add(key));
    try {
      await ref.read(appliancesProvider.notifier).command(a.id, key, value);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(applianceCommandError(l10n, a.name, e));
    } finally {
      if (mounted) {
        setState(() {
          _sending.remove(key);
          _drag.remove(key);
        });
      }
    }
  }

  Future<void> _confirmRemove(Appliance a) async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.applRemoveAsk(a.name)),
        content: Text(l10n.applRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.applRemove),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(appliancesProvider.notifier).remove(a.id);
      if (!mounted) return;
      AppToast.success(l10n.applRemovedToast(a.name));
      applianceBack(context);
    } catch (_) {
      if (mounted) AppToast.error(l10n.applRemoveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(
      authProvider.select((s) => s.user?.isAdmin ?? false),
    );
    final list = ref.watch(appliancesProvider);
    final a =
        list.value?.where((x) => x.id == widget.id).firstOrNull ??
        widget.appliance;

    if (a == null) {
      return Scaffold(
        backgroundColor: AppColors.bgSoft,
        appBar: TopNavBar(
          title: 'Home Appliances',
          onBack: () => applianceBack(context),
        ),
        body: list.isLoading
            ? const PageLoading()
            : ListEmptyState(
                centered: true,
                icon: Icons.devices_other_outlined,
                title: l10n.applErrUnavailable,
              ),
      );
    }

    final others = [
      for (final c in a.capabilities)
        if (c.key != Appliance.power && (c.isInt || c.isEnum || c.isBool)) c,
    ];

    return Scaffold(
      backgroundColor: AppColors.bgSoft,
      appBar: TopNavBar(
        title: a.name,
        onBack: () => applianceBack(context),
        actions: [
          if (a.removable && isAdmin)
            IconButton(
              tooltip: l10n.applRemove,
              icon: const Icon(Icons.power_off_rounded),
              onPressed: () => _confirmRemove(a),
            ),
        ],
      ),
      body: ApplianceLiveUpdates(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_hero(a) case final hero?) ...[
              hero,
              const SizedBox(height: 12),
            ],
            _Card(
              child: _Header(appliance: a, sending: _sending, send: _send),
            ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isAdmin && others.any((c) => c.adminOnly)) ...[
                      const _LockNote(),
                      const Divider(height: 24),
                    ],
                    for (var i = 0; i < others.length; i++) ...[
                      if (i > 0) const Divider(height: 24),
                      _control(a, others[i], isAdmin),
                    ],
                  ],
                ),
              ),
            ],
            // What it is set to comes first (it is what is changed here); how
            // it is doing, and the check, below it.
            const SizedBox(height: 12),
            _Card(
              child: ApplianceStatusPanel(
                appliance: a,
                onCheck: _checkNow,
                checking: _checking,
              ),
            ),
            if (a.kind == 'heater') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.applHeaterNote,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _Activity(appliance: a),
          ],
        ),
      ),
    );
  }

  Widget _control(Appliance a, ApplianceCapability c, bool isAdmin) {
    final l10n = context.l10n;
    final locked = c.adminOnly && !isAdmin;
    final enabled = a.online && !locked && !_sending.contains(c.key);
    final label = capabilityLabel(l10n, c.key);

    Widget body;
    if (c.isInt) {
      final current = (a.intValue(c.key) ?? c.min)
          .clamp(c.min, c.max)
          .toDouble();
      final shown = _drag[c.key] ?? current;
      body = Column(
        children: [
          Row(
            children: [
              Expanded(child: _Label(label)),
              Text(
                valueText(l10n, c, shown.round()),
                style: const TextStyle(
                  color: AppColors.deepNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: shown,
            min: c.min.toDouble(),
            max: c.max.toDouble(),
            divisions: c.max - c.min <= 100 ? c.max - c.min : null,
            activeColor: AppColors.softBlue,
            onChanged: enabled ? (v) => setState(() => _drag[c.key] = v) : null,
            onChangeEnd: enabled ? (v) => _send(a, c.key, v.round()) : null,
          ),
        ],
      );
    } else if (c.isEnum) {
      final current = a.state[c.key];
      // A mode reads faster as a sign than as a word, with its name beside the
      // label (as the temperature has its degrees) and on a long press. If
      // the app has no sign for one of them, they are all written out.
      final signs = c.key == 'mode'
          ? [for (final o in c.options) modeIcon(o)]
          : const <IconData?>[];
      final asSigns = signs.isNotEmpty && !signs.contains(null);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (asSigns && current is String)
            Row(
              children: [
                Expanded(child: _Label(label)),
                Text(
                  optionLabel(l10n, current),
                  style: const TextStyle(
                    color: AppColors.deepNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          else
            _Label(label),
          const SizedBox(height: 8),
          if (asSigns)
            Row(
              children: [
                for (var i = 0; i < c.options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: optionLabel(l10n, c.options[i]),
                      excludeFromSemantics: true,
                      child: ChoiceChip(
                        key: ValueKey('option-${c.key}-${c.options[i]}'),
                        label: Center(
                          child: Icon(
                            signs[i],
                            size: 22,
                            color: current == c.options[i]
                                ? AppColors.deepNavy
                                : AppColors.textMuted,
                            semanticLabel: optionLabel(l10n, c.options[i]),
                          ),
                        ),
                        showCheckmark: false,
                        labelPadding: EdgeInsets.zero,
                        selected: current == c.options[i],
                        onSelected: enabled
                            ? (_) => _send(a, c.key, c.options[i])
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in c.options)
                  ChoiceChip(
                    key: ValueKey('option-${c.key}-$o'),
                    label: Text(optionLabel(l10n, o)),
                    selected: current == o,
                    onSelected: enabled ? (_) => _send(a, c.key, o) : null,
                  ),
              ],
            ),
        ],
      );
    } else {
      body = Row(
        children: [
          Expanded(child: _Label(label)),
          Switch.adaptive(
            value: a.state[c.key] == true,
            activeThumbColor: AppColors.softBlue,
            onChanged: enabled ? (v) => _send(a, c.key, v) : null,
          ),
        ],
      );
    }

    return body;
  }
}

/// Said once for the whole card: a member sees the controls but cannot move
/// them.
class _LockNote extends StatelessWidget {
  const _LockNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.applAdminOnly,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: child,
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textMain,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.appliance,
    required this.sending,
    required this.send,
  });

  final Appliance appliance;
  final Set<String> sending;
  final Future<void> Function(Appliance, String, Object) send;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = appliance;
    final on = a.online && a.isOn;
    final tint = on ? AppColors.softBlue : AppColors.textMuted;
    final canSwitch =
        a.online && a.hasPower && !sending.contains(Appliance.power);

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.withValues(alpha: .12),
          ),
          child: Icon(applianceIcon(a.kind), color: tint, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.name,
                style: const TextStyle(
                  color: AppColors.deepNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (a.room != null) a.room!,
                  if (a.brand != null || a.model != null)
                    [a.brand, a.model].whereType<String>().join(' '),
                  if (a.connection == 'demo') l10n.applSimulated,
                  // The degrees are on the drawing's display and the control
                  // below it, so not here too.
                  ...applianceSettings(l10n, a, temperature: false),
                ].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Offline, a switch (even a locked one) would claim a state nobody
        // can vouch for; the status card says what was last known.
        if (a.hasPower && a.online)
          Switch.adaptive(
            value: a.isOn,
            activeThumbColor: AppColors.softBlue,
            onChanged: canSwitch ? (v) => send(a, Appliance.power, v) : null,
          ),
      ],
    );
  }
}

/// Who sent what to this appliance lately.
class _Activity extends ConsumerWidget {
  const _Activity({required this.appliance});
  final Appliance appliance;

  String _text(AppLocalizations l10n, ApplianceEvent e) {
    if (e.isAutoOff) return l10n.applAutoOffEvent;
    final who = e.userName ?? l10n.applSomeone;
    if (e.capability == Appliance.power) {
      return e.value == true ? l10n.applEventOn(who) : l10n.applEventOff(who);
    }
    return l10n.applEventSet(
      who,
      capabilityLabel(l10n, e.capability),
      valueText(l10n, appliance.capability(e.capability), e.value),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final events = ref.watch(applianceEventsProvider(appliance.id));
    final fmt = DateFormat(
      'd MMM HH:mm',
      Localizations.localeOf(context).toString(),
    );

    Widget body = events.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Row(
        children: [
          Expanded(
            child: Text(
              l10n.applActivityFailed,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.invalidate(applianceEventsProvider(appliance.id)),
            child: Text(l10n.commonTryAgain),
          ),
        ],
      ),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            l10n.applActivityEmpty,
            style: const TextStyle(color: AppColors.textMuted),
          );
        }
        return Column(
          children: [
            for (final e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(_text(l10n, e))),
                    const SizedBox(width: 12),
                    Text(
                      fmt.format(e.at.toLocal()),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            l10n.applActivityTitle,
            style: const TextStyle(
              color: AppColors.deepNavy,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        _Card(child: body),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../models/appliance_catalog.dart';
import '../shared/app_colors.dart';
import '../state/appliances_provider.dart';
import '../state/auth_state.dart';
import '../widgets/appliances/appliance_text.dart';
import '../widgets/list_empty_state.dart';
import '../widgets/toast.dart';
import '../widgets/top_nav_bar.dart';

/// Adding an appliance, in three short steps: what it is, a few details, and
/// how it will be reached (with what that needs).
///
/// Only the simulated connection can be made today. The others are shown with
/// everything they will need, so the household knows what to get ready.
class ApplianceAddScreen extends ConsumerStatefulWidget {
  const ApplianceAddScreen({super.key});

  @override
  ConsumerState<ApplianceAddScreen> createState() => _ApplianceAddScreenState();
}

class _ApplianceAddScreenState extends ConsumerState<ApplianceAddScreen> {
  static const _steps = 3;

  int _step = 0;
  String _kind = 'aircon';
  ConnectionMethod _method = ConnectionMethod.demo;
  bool _saving = false;

  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _customRoom = TextEditingController();

  /// A key of [_roomLabels], or [_otherRoom].
  String? _room;
  bool _nameTouched = false;
  bool _showNameError = false;

  static const _otherRoom = 'other';

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _customRoom.dispose();
    super.dispose();
  }

  Map<String, String> _roomLabels(AppLocalizations l10n) => {
    'living': l10n.applRoomLiving,
    'bedroom': l10n.applRoomBedroom,
    'kitchen': l10n.applRoomKitchen,
    'bathroom': l10n.applRoomBathroom,
    'study': l10n.applRoomStudy,
    'garage': l10n.applRoomGarage,
  };

  /// The room as it will be saved: the words, in the language in use now.
  String? _roomText(AppLocalizations l10n) {
    final r = _room;
    if (r == null) return null;
    if (r == _otherRoom) {
      final t = _customRoom.text.trim();
      return t.isEmpty ? null : t;
    }
    return _roomLabels(l10n)[r];
  }

  /// A name to start from, until the person types their own.
  void _suggestName(AppLocalizations l10n) {
    if (_nameTouched) return;
    final room = _roomText(l10n);
    final kind = kindLabel(l10n, _kind);
    _name.text = room == null ? kind : '$room $kind';
  }

  bool get _isAdmin => ref.read(authProvider).user?.isAdmin ?? false;

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _step = 1;
        _showNameError = true;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final made = await ref
          .read(appliancesProvider.notifier)
          .add(
            name: name,
            kind: _kind,
            room: _roomText(l10n),
            brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
            model: _model.text.trim().isEmpty ? null : _model.text.trim(),
          );
      if (!mounted) return;
      // Land on the new appliance, with the list one step back, then say so.
      context.pushReplacement(
        '/appliances/${Uri.encodeComponent(made.id)}',
        extra: made,
      );
      AppToast.success(l10n.applAddedToast(made.name));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(
        applianceErrorText(l10n, e) == l10n.applErrUnavailable
            ? l10n.applAddFailed
            : applianceErrorText(l10n, e),
      );
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      applianceBack(context);
    }
  }

  void _next() {
    final l10n = context.l10n;
    if (_step == 0) {
      setState(() {
        _step = 1;
        _suggestName(l10n);
      });
      return;
    }
    if (_step == 1) {
      if (_name.text.trim().isEmpty) {
        setState(() => _showNameError = true);
        return;
      }
      setState(() => _step = 2);
      return;
    }
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.bgSoft,
        appBar: TopNavBar(
          title: l10n.applAddTitle,
          onBack: () => applianceBack(context),
        ),
        body: ListEmptyState(
          centered: true,
          icon: Icons.lock_outline_rounded,
          title: l10n.applAddAdminOnly,
        ),
      );
    }

    final lastStep = _step == _steps - 1;
    final canFinish = lastStep ? _method.available && !_saving : true;
    final titles = [
      l10n.applStepKind,
      l10n.applStepDetails,
      l10n.applStepConnect,
    ];

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgSoft,
        appBar: TopNavBar(title: l10n.applAddTitle, onBack: _back),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? AppColors.softBlue
                              : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < _steps - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l10n.applStepOf('${_step + 1}', '$_steps')} · ${titles[_step]}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _kindStep(l10n),
                    1 => _detailsStep(l10n),
                    _ => _connectStep(l10n),
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _back,
                          child: Text(l10n.applBack),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: canFinish ? _next : null,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                lastStep ? l10n.applAddButton : l10n.applNext,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── step 1: what is it ────────────────────────────────────────────────────

  Widget _kindStep(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final k in kApplianceKinds) ...[
          _Choice(
            key: ValueKey('kind-$k'),
            icon: applianceIcon(k),
            title: kindLabel(l10n, k),
            subtitle: kindHint(l10n, k),
            selected: _kind == k,
            large: k == 'aircon',
            onTap: () => setState(() => _kind = k),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ── step 2: details ───────────────────────────────────────────────────────

  Widget _detailsStep(AppLocalizations l10n) {
    final rooms = _roomLabels(l10n);
    final brands = switch (_kind) {
      'aircon' => kAirconBrands,
      'cooler' => kCoolerBrands,
      _ => const <String>[],
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const ValueKey('name'),
          controller: _name,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            _nameTouched = true;
            if (_showNameError) setState(() => _showNameError = false);
          },
          decoration: InputDecoration(
            labelText: l10n.applFieldName,
            hintText: l10n.applFieldNameHint,
            errorText: _showNameError ? l10n.applFieldRequired : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 18),
        _Label('${l10n.applFieldRoom} · ${l10n.applFieldOptional}'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in rooms.entries)
              ChoiceChip(
                key: ValueKey('room-${e.key}'),
                label: Text(e.value),
                selected: _room == e.key,
                onSelected: (on) => setState(() {
                  _room = on ? e.key : null;
                  _suggestName(l10n);
                }),
              ),
            ChoiceChip(
              key: const ValueKey('room-other'),
              label: Text(l10n.applRoomOther),
              selected: _room == _otherRoom,
              onSelected: (on) => setState(() {
                _room = on ? _otherRoom : null;
                _suggestName(l10n);
              }),
            ),
          ],
        ),
        if (_room == _otherRoom) ...[
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('custom-room'),
            controller: _customRoom,
            onChanged: (_) => _suggestName(l10n),
            decoration: InputDecoration(
              hintText: l10n.applRoomCustomHint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _Label('${l10n.applFieldBrand} · ${l10n.applFieldOptional}'),
        TextField(
          key: const ValueKey('brand'),
          controller: _brand,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (brands.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final b in brands)
                ActionChip(
                  label: Text(b),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _brand.text = b),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _Label('${l10n.applFieldModel} · ${l10n.applFieldOptional}'),
        TextField(
          key: const ValueKey('model'),
          controller: _model,
          decoration: InputDecoration(
            hintText: l10n.applFieldModelHint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ── step 3: how it connects ───────────────────────────────────────────────

  Widget _connectStep(AppLocalizations l10n) {
    final caveat = connectionCaveat(l10n, _method);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            l10n.applConnTitle,
            style: const TextStyle(
              color: AppColors.deepNavy,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        for (final m in ConnectionMethod.values) ...[
          _Choice(
            key: ValueKey('conn-${m.id}'),
            icon: connectionIcon(m),
            title: connectionTitle(l10n, m),
            subtitle: connectionSummary(l10n, m),
            selected: _method == m,
            tag: m.available ? null : l10n.applConnSoon,
            onTap: () => setState(() => _method = m),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Container(
          key: const ValueKey('requirements'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.applConnNeed} · ${connectionTitle(l10n, _method)}',
                style: const TextStyle(
                  color: AppColors.deepNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (final r in connectionRequirements(l10n, _method))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: _method.available
                            ? AppColors.softBlue
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r)),
                    ],
                  ),
                ),
              if (caveat != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          caveat,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_method.available) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.applConnUnavailable,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );
}

/// A tappable card that is either picked or not.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.tag,
    this.large = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? tag;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? AppColors.softBlue : AppColors.textMuted;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFFEAF1FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.softBlue : AppColors.cardBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(large ? 18 : 14),
            child: Row(
              children: [
                Container(
                  width: large ? 52 : 44,
                  height: large ? 52 : 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tint.withValues(alpha: .12),
                  ),
                  child: Icon(icon, color: tint, size: large ? 28 : 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.deepNavy,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          if (tag != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgSoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Text(
                                tag!,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.softBlue,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

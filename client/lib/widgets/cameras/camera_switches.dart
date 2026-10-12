import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/home_camera.dart';
import '../../repositories/cameras_repository.dart';
import '../../shared/app_colors.dart';
import '../../state/cameras_provider.dart';
import '../toast.dart';

/// The camera's own on/off settings: privacy mode, motion and person
/// detection. Only the ones this camera reports having are shown.
class CameraSwitches extends ConsumerStatefulWidget {
  const CameraSwitches({super.key, required this.camera});
  final HomeCamera camera;

  @override
  ConsumerState<CameraSwitches> createState() => _CameraSwitchesState();
}

class _CameraSwitchesState extends ConsumerState<CameraSwitches> {
  /// Settings with a change in flight: not flippable again until it lands.
  final Set<String> _sending = {};

  Future<void> _toggle(String key, bool on) async {
    final l10n = context.l10n;
    setState(() => _sending.add(key));
    try {
      await ref
          .read(cameraSwitchesProvider(widget.camera.id).notifier)
          .set(key, on);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        e is CameraException && e.failure == CameraFailure.unsupported
            ? l10n.camNotSupported
            : l10n.camSwitchFailed,
      );
    } finally {
      if (mounted) setState(() => _sending.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cam = widget.camera;
    final states = ref.watch(cameraSwitchesProvider(cam.id));

    if (states.hasError && !states.hasValue) {
      return Row(
        children: [
          Expanded(
            child: Text(
              l10n.camSwitchesLoadFailed,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(cameraSwitchesProvider(cam.id)),
            child: Text(l10n.commonTryAgain),
          ),
        ],
      );
    }

    final loaded = states.value;
    Widget tile(String key, IconData icon, String title, {String? hint}) {
      if (!cam.switches.contains(key)) return const SizedBox.shrink();
      final on = loaded?[key] ?? false;
      return _SwitchTile(
        icon: icon,
        title: title,
        hint: hint,
        value: on,
        // Until the state is known, show the tile but don't let it be flipped
        // blindly.
        enabled: loaded != null && !_sending.contains(key),
        onChanged: (v) => _toggle(key, v),
      );
    }

    return Column(
      children: [
        tile(
          'privacy',
          Icons.visibility_off_rounded,
          l10n.camSwitchPrivacy,
          hint: l10n.camSwitchPrivacyHint,
        ),
        tile('motion', Icons.directions_run_rounded, l10n.camSwitchMotion),
        tile('human', Icons.person_search_rounded, l10n.camSwitchHuman),
        tile(
          'light',
          Icons.lightbulb_rounded,
          l10n.camSwitchLight,
          hint: l10n.camSwitchLightHint,
        ),
        tile('light_auto', Icons.flare_rounded, l10n.camSwitchLightAuto),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: AppColors.softBlue,
      secondary: Icon(icon, color: AppColors.softBlue),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textMain,
        ),
      ),
      subtitle: hint == null ? null : Text(hint!),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

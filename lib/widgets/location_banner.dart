import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../shared/app_colors.dart';
import '../state/location_controller.dart';
import '../l10n/l10n.dart';

/// Shows nothing while location works, a thin progress bar while it is being
/// resolved, and an actionable banner when it can't be used.
class LocationBanner extends ConsumerWidget {
  const LocationBanner({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  });

  /// Space around the banner card (so it can sit flush on a map overlay).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(locationControllerProvider);
    final ctrl = ref.read(locationControllerProvider.notifier);

    final issue = s.issue;
    if (issue == null) {
      return s.resolving && s.location == null
          ? const LinearProgressIndicator(minHeight: 2)
          : const SizedBox.shrink();
    }

    final (message, actionLabel, action) = switch (issue) {
      LocationIssue.serviceDisabled => (
        context.l10n.locServiceOff,
        context.l10n.locOpenSettings,
        () => Geolocator.openLocationSettings(),
      ),
      LocationIssue.permissionDenied => (
        context.l10n.locDenied,
        context.l10n.locAllow,
        () => ctrl.refresh(),
      ),
      LocationIssue.permissionDeniedForever => (
        context.l10n.locBlocked,
        context.l10n.locOpenSettings,
        () => Geolocator.openAppSettings(),
      ),
      LocationIssue.unavailable => (
        context.l10n.locUnavailable,
        null,
        null,
      ),
    };

    // Same card language as the rest of the app (white, hairline border, soft
    // shadow); the blue icon carries the "needs attention" signal.
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              offset: Offset(0, 4),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: AppColors.softBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 13.5,
                  height: 1.3,
                ),
              ),
            ),
            if (action != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.softBlue,
                ),
                onPressed: action,
                child: Text(actionLabel!),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.softBlue),
              onPressed: () => ctrl.refresh(),
              child: Text(context.l10n.commonTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

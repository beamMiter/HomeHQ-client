import 'package:flutter/material.dart';

import '../../shared/app_colors.dart';
import '../../utils/geo.dart';
import '../../l10n/l10n.dart';

/// Bottom panel shown while the distance tool is active.
class MeasureCard extends StatelessWidget {
  const MeasureCard({
    super.key,
    required this.points,
    required this.meters,
    required this.canStartFromMe,
    required this.onStartFromMe,
    required this.onUndo,
    required this.onClear,
    required this.onDone,
  });

  final int points;
  final double meters;
  final bool canStartFromMe;
  final VoidCallback onStartFromMe;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = switch (points) {
      0 => context.l10n.contMeasureHint0,
      1 => context.l10n.contMeasureHint1,
      _ => context.l10n.contMeasureHintMore,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            offset: Offset(0, 6),
            color: Color(0x26000000),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.straighten_rounded,
                size: 22,
                color: AppColors.deepNavy,
              ),
              const SizedBox(width: 8),
              Text(
                points < 2 ? context.l10n.distMeters('0') : formatDistance(meters, context.l10n),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  context.l10n.contPoints(points),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Wrap(
            children: [
              if (canStartFromMe)
                TextButton.icon(
                  onPressed: onStartFromMe,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(context.l10n.contStartFromMe),
                ),
              TextButton.icon(
                onPressed: points == 0 ? null : onUndo,
                icon: const Icon(Icons.undo, size: 18),
                label: Text(context.l10n.contUndo),
              ),
              TextButton.icon(
                onPressed: points == 0 ? null : onClear,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(context.l10n.commonClear),
              ),
              TextButton(onPressed: onDone, child: Text(context.l10n.contDone)),
            ],
          ),
        ],
      ),
    );
  }
}

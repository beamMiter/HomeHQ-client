import 'package:flutter/material.dart';

import '../../shared/app_colors.dart';
import '../../l10n/l10n.dart';

/// Search-radius picker. Resolves to the chosen radius in metres, or null if
/// dismissed.
///
/// Only the committed value is returned (on release / on tapping a preset), so
/// dragging the slider doesn't fire a search for every tick.
Future<int?> showRadiusSheet(BuildContext context, {required int current}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _RadiusSheet(currentMeters: current),
  );
}

class _RadiusSheet extends StatefulWidget {
  const _RadiusSheet({required this.currentMeters});
  final int currentMeters;

  @override
  State<_RadiusSheet> createState() => _RadiusSheetState();
}

class _RadiusSheetState extends State<_RadiusSheet> {
  static const _min = 1.0, _max = 20.0;
  static const _presets = [3, 5, 10, 20];

  late double _km = (widget.currentMeters / 1000).clamp(_min, _max);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.contRadiusTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.contRadiusFromYou(_km.round()),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.softBlue,
              ),
            ),
            Slider(
              value: _km,
              min: _min,
              max: _max,
              divisions: (_max - _min).round(),
              label: context.l10n.distKm('${_km.round()}'),
              onChanged: (v) => setState(() => _km = v),
              onChangeEnd: (v) => Navigator.of(context).pop((v * 1000).round()),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(context.l10n.distKm('$p')),
                    selected: _km.round() == p,
                    onSelected: (_) => Navigator.of(context).pop(p * 1000),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

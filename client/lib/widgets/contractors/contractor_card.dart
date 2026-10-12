import 'package:flutter/material.dart';

import '../../models/contractor.dart';
import '../../models/contractor_type.dart';
import '../../shared/app_colors.dart';
import '../../utils/geo.dart';
import '../../l10n/l10n.dart';

/// One contractor in the results sheet. Tapping selects it; the selected card
/// grows to show its actions and contact channels.
///
/// The collapsed height is fixed (see [collapsedHeight]) so the sheet can
/// scroll straight to any card by index; only the selected card changes size.
class ContractorCard extends StatelessWidget {
  const ContractorCard({
    super.key,
    required this.contractor,
    required this.meters,
    required this.selected,
    required this.onTap,
    this.starred = false,
    this.onToggleStar,
    this.onCall,
    this.callLoading = false,
    this.onDirections,
    this.onMeasure,
    this.onOpenInGoogle,
    this.onOpenWebsite,
  });

  final Contractor contractor;

  /// Live distance from the user, or null when unknown.
  final double? meters;
  final bool selected;
  final VoidCallback onTap;

  /// Whether the household starred this one, and how to flip it.
  final bool starred;
  final VoidCallback? onToggleStar;

  final VoidCallback? onCall;

  /// True while a Google place's phone number is still being fetched, so the
  /// call button can say "wait" instead of silently not being there.
  final bool callLoading;
  final VoidCallback? onDirections;
  final VoidCallback? onMeasure;

  /// Contact channels beyond the phone, taken from what the place publishes on
  /// Google. Shown as small links under the main actions.
  final VoidCallback? onOpenInGoogle;
  final VoidCallback? onOpenWebsite;

  static const double collapsedHeight = 88;
  static const double _actionsHeight = 58; // main action row + padding
  static const double _linksHeight = 46; // the extra links row

  bool get _hasLinks => onOpenInGoogle != null || onOpenWebsite != null;

  double get _expandedHeight =>
      collapsedHeight + _actionsHeight + (_hasLinks ? _linksHeight : 0);

  @override
  Widget build(BuildContext context) {
    final type = contractorTypeFor(contractor.types);
    final address = contractor.address?.trim() ?? '';
    final phone = contractor.phone?.trim() ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: selected ? _expandedHeight : collapsedHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.softBlue : AppColors.cardBorder,
          width: selected ? 1.6 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  color: AppColors.softBlue.withValues(alpha: 0.16),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SingleChildScrollView(
            // The card animates between two heights; the content below is laid
            // out for the larger one and clipped while it grows.
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
              child: Column(
                children: [
                  SizedBox(
                    height: collapsedHeight - 24,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.bgSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            type.icon,
                            color: AppColors.softBlue,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contractor.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // One line: trade, rating, hours, then where.
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: type.name(context.l10n),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.softBlue,
                                      ),
                                    ),
                                    if (contractor.rating != null)
                                      TextSpan(
                                        text: '  ·  ★ ${_rating(contractor)}',
                                        style: const TextStyle(
                                          color: AppColors.textMain,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (contractor.openNow != null)
                                      TextSpan(
                                        text: contractor.openNow!
                                            ? '  ·  ${context.l10n.contOpenNow}'
                                            : '  ·  ${context.l10n.contClosedNow}',
                                        style: TextStyle(
                                          color: contractor.openNow!
                                              ? AppColors.softBlue
                                              : AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (address.isNotEmpty)
                                      TextSpan(
                                        text: '  ·  $address',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (meters != null) ...[
                          const SizedBox(width: 6),
                          _DistanceBadge(meters: meters!),
                        ],
                        if (onToggleStar != null)
                          IconButton(
                            tooltip: starred ? context.l10n.contStarRemove : context.l10n.contStarAdd,
                            onPressed: onToggleStar,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              starred
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: starred
                                  ? AppColors.softBlue
                                  : AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    SizedBox(
                      height: _actionsHeight - 10,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          children: [
                            if (onCall != null || callLoading)
                              Expanded(
                                flex: 5,
                                child: _ActionButton(
                                  icon: Icons.call_rounded,
                                  // The number itself: it is the contact
                                  // channel, so show it instead of "Call".
                                  label: phone.isEmpty ? context.l10n.contCall : phone,
                                  busy: callLoading,
                                  onTap: onCall,
                                ),
                              ),
                            if (onDirections != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: _ActionButton(
                                  icon: Icons.directions_rounded,
                                  label: context.l10n.contDirections,
                                  filled: true,
                                  onTap: onDirections,
                                ),
                              ),
                            ],
                            if (onMeasure != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: _ActionButton(
                                  icon: Icons.straighten_rounded,
                                  label: context.l10n.contMeasure,
                                  onTap: onMeasure,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_hasLinks)
                      SizedBox(
                        height: _linksHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Row(
                            children: [
                              if (onOpenWebsite != null)
                                _LinkChip(
                                  icon: Icons.language_rounded,
                                  label: context.l10n.contWebsite,
                                  onTap: onOpenWebsite!,
                                ),
                              if (onOpenWebsite != null &&
                                  onOpenInGoogle != null)
                                const SizedBox(width: 8),
                              if (onOpenInGoogle != null)
                                _LinkChip(
                                  icon: Icons.open_in_new_rounded,
                                  label: context.l10n.contOpenInGoogle,
                                  onTap: onOpenInGoogle!,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _rating(Contractor c) {
    final r = c.rating!.toStringAsFixed(1);
    return c.ratingCount == null ? r : '$r (${c.ratingCount})';
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.meters});
  final double meters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        formatDistance(meters, context.l10n),
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: AppColors.softBlue,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;

  /// Null disables the button (e.g. while [busy]).
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // Primary action in the brand blue; the rest quiet, on the soft tint.
    final fg = filled ? Colors.white : AppColors.deepNavy;
    return Material(
      color: filled ? AppColors.softBlue : AppColors.bgSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small outlined link: a contact channel that isn't a primary action.
class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.softBlue),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

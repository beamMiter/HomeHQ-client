import 'package:flutter/material.dart';

import '../shared/app_colors.dart';

/// The card every list uses for one item.
///
/// One rule, the same on every list: the whole card is what you tap, and a
/// ">" at its right end says "this opens". Nothing else on a card looks
/// tappable unless it is a button of its own. Lists give the cards a 12 px
/// side margin and 8 px between them.
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  /// What the card says. It should not draw its own ">".
  final Widget child;

  /// Opens the item. Null = nothing opens, and no ">" is drawn.
  final VoidCallback? onTap;

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(child: child),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: AppColors.textMuted,
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

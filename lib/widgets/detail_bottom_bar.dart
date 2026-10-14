import 'package:flutter/material.dart';

import '../shared/app_colors.dart';

/// One button on a [DetailBottomBar].
class DetailAction {
  const DetailAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Shows a spinner and ignores taps while it works.
  final bool busy;
}

/// The bar at the bottom of every detail page: the one thing you most likely
/// want to do next, as a wide filled button, and at most one alternative
/// beside it. Everything else on the page lives in the "⋯" menu (see
/// MoreMenuButton), so every detail page has the same two places to look.
class DetailBottomBar extends StatelessWidget {
  const DetailBottomBar({super.key, required this.primary, this.secondary});

  final DetailAction primary;
  final DetailAction? secondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                if (secondary != null) ...[
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: secondary!.busy ? null : secondary!.onPressed,
                      icon: Icon(secondary!.icon),
                      label: Text(
                        secondary!.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: _shape(OutlinedButton.styleFrom()),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: primary.busy ? null : primary.onPressed,
                    icon: primary.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(primary.icon),
                    label: Text(
                      primary.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: _shape(FilledButton.styleFrom()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static ButtonStyle _shape(ButtonStyle base) => base.copyWith(
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

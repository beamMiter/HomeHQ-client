import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// One line of a [MoreMenuButton].
class MoreMenuItem {
  const MoreMenuItem({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Drawn in red, for things that delete or cancel.
  final bool destructive;
}

/// The "⋯" button: the other things you can do with the item you are looking
/// at (edit, attach, delete…). It sits in the same place everywhere — the top
/// right of a detail page, or the end of a note's action row — so a person
/// learns once where "more" is.
class MoreMenuButton extends StatelessWidget {
  const MoreMenuButton({super.key, required this.items});

  final List<MoreMenuItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<int>(
      tooltip: context.l10n.commonMore,
      icon: const Icon(Icons.more_horiz),
      onSelected: (i) => items[i].onSelected(),
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(
                  items[i].icon,
                  size: 20,
                  color: items[i].destructive ? Colors.red : null,
                ),
                const SizedBox(width: 12),
                // A long label shortens instead of running out of the menu.
                Flexible(
                  child: Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: items[i].destructive
                        ? const TextStyle(color: Colors.red)
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

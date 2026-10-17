import 'package:flutter/material.dart';

class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  const TopNavBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.backgroundColor,
    this.onBack,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final Color? backgroundColor;

  /// What the back arrow does. By default it pops the page, and does nothing
  /// when there is no page below (the app restarted on this one, or it was
  /// opened by a link): pass this where that must lead somewhere.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(title),
      actions: [...(actions ?? const []), const SizedBox(width: 4)],
    );
  }
}

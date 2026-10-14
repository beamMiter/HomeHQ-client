import 'package:flutter/material.dart';

/// The "new …" button at the bottom right of a list screen: a round button
/// with a plus. The words live in [tooltip] (long-press, and read by screen
/// readers), so the button stays small and the same on every list.
class AddFab extends StatelessWidget {
  const AddFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.color,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: tooltip,
      onPressed: onPressed,
      backgroundColor: color,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      highlightElevation: 6,
      child: const Icon(Icons.add_rounded, size: 30),
    );
  }
}

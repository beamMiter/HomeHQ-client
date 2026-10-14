// lib/widgets/toast.dart
import 'package:flutter/material.dart';

import '../shared/app_colors.dart';

enum ToastType { success, error, info }

/// The app's one way to show a short message.
///
/// Built on Flutter's [ScaffoldMessenger] (floating Material snack bars) rather
/// than an overlay package: that is what Material specifies and what most
/// Flutter apps use, and it already does the platform work. It sits above the
/// FAB, bottom bars and keyboard, respects safe areas, can be swiped away and
/// is announced to screen readers.
///
/// Following the Material snackbar guidance: an opaque dark container with
/// light text (so it reads on any page without needing a shadow), one message
/// at a time, at least 4 seconds on screen, at most two lines.
///
/// It needs no [BuildContext], so it can be called from providers, repositories
/// and interceptors as well as widgets:
///
/// ```dart
/// AppToast.success('บันทึกแล้ว');
/// AppToast.error('เชื่อมต่อไม่ได้');
/// ```
///
/// Requires `MaterialApp(scaffoldMessengerKey: AppToast.messengerKey)`.
class AppToast {
  AppToast._();

  /// Hand this to the root [MaterialApp].
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void success(String message, {Duration? duration}) =>
      _show(message, ToastType.success, duration);

  static void error(String message, {Duration? duration}) =>
      _show(message, ToastType.error, duration);

  static void info(String message, {Duration? duration}) =>
      _show(message, ToastType.info, duration);

  /// Dismiss the visible toast and drop anything queued behind it.
  static void clear() => messengerKey.currentState?.clearSnackBars();

  static void _show(String message, ToastType type, Duration? duration) {
    final messenger = messengerKey.currentState;
    if (messenger == null || message.trim().isEmpty) return;

    // Latest wins. Stacking a queue of stale messages is worse than replacing
    // one: by the time the 4th is shown the user has long moved on.
    messenger
      ..clearSnackBars()
      ..showSnackBar(_build(message.trim(), type, duration));
  }

  static SnackBar _build(String message, ToastType type, Duration? duration) {
    // The status shows in the icon only; the container stays one neutral tone.
    final (icon, tint) = switch (type) {
      ToastType.success => (Icons.check_circle_rounded, _green),
      ToastType.error => (Icons.error_rounded, _red),
      ToastType.info => (Icons.info_rounded, _blue),
    };

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      // Flat, no drop shadow: a dark container needs none to stand apart.
      elevation: 0,
      backgroundColor: AppColors.deepNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration:
          duration ??
          switch (type) {
            // Material: at least 4 s. Errors get longer, they are read, not
            // glanced at.
            ToastType.error => const Duration(seconds: 6),
            _ => const Duration(seconds: 4),
          },
      // A way out for errors, so a long message is never stuck on screen.
      showCloseIcon: type == ToastType.error,
      closeIconColor: Colors.white70,
      content: Row(
        children: [
          Icon(icon, size: 20, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lighter shades of the status colours, chosen to read on the dark container.
  static const _green = Color(0xFF4ADE80);
  static const _red = Color(0xFFF87171);
  static const _blue = Color(0xFF93C5FD);
}

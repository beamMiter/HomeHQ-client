// lib/widgets/toast.dart
import 'dart:async';

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
///
/// **How it leaves.** A Material 3 floating snack bar leaves with a fade of
/// about 50 ms and no movement, which reads as a jump. So the snack bar here is
/// only a see-through carrier (it still does the placing, the announcing and
/// the swipe), and the dark container the user sees is drawn by the toast
/// itself: it stays for its time, then fades and sinks over [exitDuration].
/// The same happens when it is cleared or closed. A toast that is replaced by
/// a newer one is swapped at once.
class AppToast {
  AppToast._();

  /// Hand this to the root [MaterialApp].
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// How long the entrance takes. Set explicitly so the stay can be counted
  /// from the end of it.
  static const enterDuration = Duration(milliseconds: 250);

  /// How long the fade-and-sink at the end takes.
  static const exitDuration = Duration(milliseconds: 300);

  /// How far the container sinks while it fades. The carrier has this much
  /// room below the container, so nothing is clipped on the way.
  static const _sink = 12.0;

  /// The toast on screen now, if any.
  static _ToastHandle? _current;

  static void success(String message, {Duration? duration}) =>
      _show(message, ToastType.success, duration);

  static void error(String message, {Duration? duration}) =>
      _show(message, ToastType.error, duration);

  static void info(String message, {Duration? duration}) =>
      _show(message, ToastType.info, duration);

  /// Dismiss the visible toast (it fades out) and drop anything queued behind it.
  static void clear() {
    if (_current?.dismiss() ?? false) return;
    messengerKey.currentState?.clearSnackBars();
  }

  /// Called when a toast has finished leaving: take its carrier off screen.
  static void _gone(_ToastHandle handle) {
    if (!identical(_current, handle)) return;
    _current = null;
    messengerKey.currentState?.removeCurrentSnackBar(
      reason: SnackBarClosedReason.hide,
    );
  }

  static void _show(String message, ToastType type, Duration? duration) {
    final messenger = messengerKey.currentState;
    if (messenger == null || message.trim().isEmpty) return;

    // Latest wins. Stacking a queue of stale messages is worse than replacing
    // one: by the time the 4th is shown the user has long moved on.
    try {
      final handle = _ToastHandle();
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          _build(message.trim(), type, duration, handle),
          snackBarAnimationStyle: AnimationStyle(duration: enterDuration),
        );
      _current = handle;
    } catch (e, stack) {
      // A message is never worth breaking what it reports on: the caller
      // goes on (to the next page, say) whatever happens here. (Seen after a
      // hot reload left a page half torn down.)
      debugPrint('⚠️ toast not shown: $e\n$stack');
    }
  }

  static SnackBar _build(
    String message,
    ToastType type,
    Duration? duration,
    _ToastHandle handle,
  ) {
    // The status shows in the icon only; the container stays one neutral tone.
    final (icon, tint) = switch (type) {
      ToastType.success => (Icons.check_circle_rounded, _green),
      ToastType.error => (Icons.error_rounded, _red),
      ToastType.info => (Icons.info_rounded, _blue),
    };
    final stay =
        duration ??
        switch (type) {
          // Material: at least 4 s. Errors get longer, they are read, not
          // glanced at.
          ToastType.error => const Duration(seconds: 6),
          _ => const Duration(seconds: 4),
        };

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      // 4 + the carrier's own bottom room = the 16 the container sits above
      // the edge.
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.only(bottom: _sink),
      // A see-through carrier with no shadow: what is seen is drawn by
      // [_ToastBody], which is what lets it fade out.
      elevation: 0,
      backgroundColor: Colors.transparent,
      // The carrier's own timer is only a backstop: the toast takes itself
      // away when its exit has finished.
      duration: stay + exitDuration + const Duration(milliseconds: 300),
      content: _ToastBody(
        handle: handle,
        stay: stay,
        icon: icon,
        tint: tint,
        message: message,
        // A way out for errors, so a long message is never stuck on screen.
        closable: type == ToastType.error,
      ),
    );
  }

  // Lighter shades of the status colours, chosen to read on the dark container.
  static const _green = Color(0xFF4ADE80);
  static const _red = Color(0xFFF87171);
  static const _blue = Color(0xFF93C5FD);
}

/// What [AppToast] keeps of the toast on screen, so it can be told to leave.
class _ToastHandle {
  _ToastBodyState? _state;

  void _attach(_ToastBodyState state) => _state = state;

  void _detach(_ToastBodyState state) {
    if (identical(_state, state)) _state = null;
    if (identical(AppToast._current, this)) AppToast._current = null;
  }

  /// Start fading out. False when there is nothing on screen to fade.
  bool dismiss() => _state?.leave() ?? false;
}

/// The dark container, its content, and its way out.
class _ToastBody extends StatefulWidget {
  const _ToastBody({
    required this.handle,
    required this.stay,
    required this.icon,
    required this.tint,
    required this.message,
    required this.closable,
  });

  final _ToastHandle handle;
  final Duration stay;
  final IconData icon;
  final Color tint;
  final String message;
  final bool closable;

  @override
  State<_ToastBody> createState() => _ToastBodyState();
}

class _ToastBodyState extends State<_ToastBody>
    with SingleTickerProviderStateMixin {
  /// 1 while it is on screen, down to 0 as it leaves.
  late final AnimationController _shown;

  /// Leaving speeds up (ease-in), the way things leave in Material motion.
  late final CurvedAnimation _curve;
  Timer? _leaveTimer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _shown = AnimationController(
      vsync: this,
      value: 1,
      duration: AppToast.exitDuration,
    );
    _curve = CurvedAnimation(
      parent: _shown,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn.flipped,
    );
    widget.handle._attach(this);
    // The carrier's entrance runs first; the stay is counted from its end.
    _leaveTimer = Timer(AppToast.enterDuration + widget.stay, leave);
  }

  /// Fade out and sink, then take the carrier away. False when it cannot.
  bool leave() {
    if (!mounted) return false;
    if (_leaving) return true;
    _leaving = true;
    _leaveTimer?.cancel();
    _shown.reverse().whenComplete(() {
      if (mounted) AppToast._gone(widget.handle);
    });
    return true;
  }

  @override
  void dispose() {
    _leaveTimer?.cancel();
    widget.handle._detach(this);
    _curve.dispose();
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _curve.value) * AppToast._sink),
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.deepNavy,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: widget.tint),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
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
              if (widget.closable) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: leave,
                  icon: const Icon(Icons.close),
                  iconSize: 18,
                  color: Colors.white70,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

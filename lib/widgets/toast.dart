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
/// **How it arrives and leaves.** A Material 3 floating snack bar fades in over
/// about 50 ms after a 100 ms wait and out in about 50 ms, without moving,
/// which reads as popping in and jumping out. So the snack bar here is only a
/// see-through carrier with no animation of its own (it still does the placing,
/// the announcing and the swipe), and the dark container the user sees is drawn
/// by the toast itself: it fades in while rising over [enterDuration], stays
/// for its time, then fades out while sinking over [exitDuration]. Clearing or
/// closing it leaves the same way, from wherever it had got to. A toast that is
/// replaced by a newer one is swapped at once, and with the device's Reduce
/// Motion on there is no movement at all.
class AppToast {
  AppToast._();

  /// Hand this to the root [MaterialApp].
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// How long the fade-and-rise on arriving takes.
  static const enterDuration = Duration(milliseconds: 250);

  /// How long the fade-and-sink at the end takes.
  static const exitDuration = Duration(milliseconds: 300);

  /// How far the container travels while it fades: up into place on arriving,
  /// down and away on leaving. The carrier has this much room below the
  /// container, so nothing is clipped on the way.
  static const _travel = 12.0;

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
          // The carrier itself does not animate: the toast does.
          snackBarAnimationStyle: AnimationStyle.noAnimation,
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
      padding: const EdgeInsets.only(bottom: _travel),
      // A see-through carrier with no shadow: what is seen is drawn by
      // [_ToastBody], which is what lets it fade out.
      elevation: 0,
      backgroundColor: Colors.transparent,
      // The carrier's own timer is only a backstop, later than the toast's whole
      // life (entrance, stay, exit): the toast takes itself away when it is done.
      duration:
          stay + enterDuration + exitDuration + const Duration(seconds: 1),
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
  /// 0 before it arrives, 1 while it is on screen, back down to 0 as it leaves.
  late final AnimationController _shown;

  /// Arriving slows down into place (ease-out); leaving speeds up (ease-in),
  /// the way things arrive and leave in Material motion.
  late final CurvedAnimation _curve;
  Timer? _leaveTimer;
  bool _leaving = false;
  bool _started = false;

  /// The device asks for no motion (Reduce Motion).
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _shown = AnimationController(
      vsync: this,
      duration: AppToast.enterDuration,
      reverseDuration: AppToast.exitDuration,
    );
    _curve = CurvedAnimation(
      parent: _shown,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn.flipped,
    );
    widget.handle._attach(this);
    _leaveTimer = Timer(AppToast.enterDuration + widget.stay, leave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _shown.value = 1;
    } else {
      _shown.forward();
    }
  }

  /// Fade out and sink, from wherever it has got to, then take the carrier
  /// away. False when it cannot.
  bool leave() {
    if (!mounted) return false;
    if (_leaving) return true;
    _leaving = true;
    _leaveTimer?.cancel();
    if (_reduceMotion) {
      AppToast._gone(widget.handle);
      return true;
    }
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
          offset: Offset(0, (1 - _curve.value) * AppToast._travel),
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

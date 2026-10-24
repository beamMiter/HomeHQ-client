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
/// by the toast itself. Like a tab tucking away, it slides up out of the bottom
/// edge over [enterDuration], stays for its time, then slides back down into
/// that edge over [exitDuration]; it does not fade. The edge is the bottom of
/// the carrier (the top of a bottom bar or button, when there is one), which
/// clips what passes below it. Clearing or closing it leaves the same way, from
/// wherever it had got to. A toast that is replaced by a newer one is swapped
/// at once, and with the device's Reduce Motion on there is no movement at all.
class AppToast {
  AppToast._();

  /// Hand this to the root [MaterialApp].
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// How long sliding up out of the bottom edge takes.
  static const enterDuration = Duration(milliseconds: 300);

  /// How long sliding back down into it takes.
  static const exitDuration = Duration(milliseconds: 300);

  /// How far above the bottom edge the container rests.
  static const _gap = 16.0;

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
      // The one being replaced will never leave by itself now.
      _current?._retire();
      final handle = _ToastHandle();
      final stay = _stayFor(type, duration);
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          _build(message.trim(), type, stay, handle),
          // The carrier itself does not animate: the toast does.
          snackBarAnimationStyle: AnimationStyle.noAnimation,
        );
      _current = handle;
      handle._leaveAfter(enterDuration + stay);
    } catch (e, stack) {
      // A message is never worth breaking what it reports on: the caller
      // goes on (to the next page, say) whatever happens here. (Seen after a
      // hot reload left a page half torn down.)
      debugPrint('⚠️ toast not shown: $e\n$stack');
    }
  }

  /// How long a toast stays up once it has arrived.
  static Duration _stayFor(ToastType type, Duration? duration) =>
      duration ??
      switch (type) {
        // Material: at least 4 s. Errors get longer, they are read, not
        // glanced at.
        ToastType.error => const Duration(seconds: 6),
        _ => const Duration(seconds: 4),
      };

  static SnackBar _build(
    String message,
    ToastType type,
    Duration stay,
    _ToastHandle handle,
  ) {
    // The status shows in the icon only; the container stays one neutral tone.
    final (icon, tint) = switch (type) {
      ToastType.success => (Icons.check_circle_rounded, _green),
      ToastType.error => (Icons.error_rounded, _red),
      ToastType.info => (Icons.info_rounded, _blue),
    };

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      // No bottom margin: the carrier's bottom is the edge the toast slides
      // into, so it sits right on the bottom bar (or the screen's edge). The
      // gap above it is inside, in [_ToastBody].
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: EdgeInsets.zero,
      // A see-through carrier with no shadow: what is seen is drawn by
      // [_ToastBody]. Square, so the edge it clips at is a straight line.
      elevation: 0,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.hardEdge,
      // The carrier's own timer is only a backstop, later than the toast's whole
      // life (entrance, stay, exit): the toast takes itself away when it is done.
      duration:
          stay + enterDuration + exitDuration + const Duration(seconds: 1),
      content: _ToastBody(
        handle: handle,
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

/// One toast, however many copies of it are on screen.
///
/// The messenger draws the toast on every page that is showing, so a page
/// change (a push, a pop, the hero flight between them) makes new copies of
/// [_ToastBody] while the old ones are still there. Each copy starts from this
/// shared state instead of from the bottom edge, so the toast does not come up
/// again; the timer and the decision to leave are here too, so every copy
/// leaves together.
class _ToastHandle {
  final _states = <_ToastBodyState>{};

  /// Where the toast is: 0 under the edge, 1 up. Kept by every copy.
  double value = 0;

  /// It has started to leave.
  bool leaving = false;

  Timer? _leaveTimer;

  void _leaveAfter(Duration delay) {
    _leaveTimer?.cancel();
    _leaveTimer = Timer(delay, leave);
  }

  /// Replaced by a newer toast: stop its timer (its copies are taken away
  /// with the carrier).
  void _retire() => _leaveTimer?.cancel();

  void _attach(_ToastBodyState state) => _states.add(state);

  void _detach(_ToastBodyState state) {
    _states.remove(state);
    if (_states.isNotEmpty) return;
    // No copy left (taken away, swiped off, replaced): nothing more to time.
    _leaveTimer?.cancel();
    if (identical(AppToast._current, this)) AppToast._current = null;
  }

  /// Start leaving, on every copy. False when it is not on screen.
  bool leave() {
    if (_states.isEmpty) return false;
    if (leaving) return true;
    leaving = true;
    _leaveTimer?.cancel();
    for (final state in _states.toList()) {
      state._leave();
    }
    return true;
  }

  /// The same as [leave], for [AppToast.clear].
  bool dismiss() => leave();
}

/// The dark container, its content, and its way out.
class _ToastBody extends StatefulWidget {
  const _ToastBody({
    required this.handle,
    required this.icon,
    required this.tint,
    required this.message,
    required this.closable,
  });

  final _ToastHandle handle;
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
  /// the way things enter and leave the screen in Material motion.
  late final CurvedAnimation _curve;
  bool _started = false;

  /// This copy's page is on screen, so its ticker runs. A copy on a page that
  /// is covered by another (the page under a pushed one) is frozen by Flutter;
  /// when that page shows again the copy catches up with the shared state
  /// instead of starting over from where it froze.
  bool _active = true;

  /// The device asks for no motion (Reduce Motion).
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    // A copy made by a page change picks up where the toast already is.
    _shown =
        AnimationController(
          vsync: this,
          value: widget.handle.value,
          duration: AppToast.enterDuration,
          reverseDuration: AppToast.exitDuration,
        )..addListener(() {
          if (_active) widget.handle.value = _shown.value;
        });
    _curve = CurvedAnimation(
      parent: _shown,
      // Gentle curves, not cubic ones: the card is only seen while it crosses
      // the edge, and a sharp curve would make that part a blink.
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn.flipped,
    );
    widget.handle._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final active = TickerMode.valuesOf(context).enabled;
    final woke = _started && active && !_active;
    _active = active;
    if (!_started) {
      _started = true;
      if (active) _follow();
    } else if (woke) {
      _follow();
    }
  }

  /// Take up the toast's shared state: where it is and which way it is going.
  void _follow() {
    if (_reduceMotion) {
      _shown.value = widget.handle.leaving ? 0 : 1;
      return;
    }
    _shown.value = widget.handle.value;
    if (widget.handle.leaving) {
      _leave(); // the other copies are already on their way down
    } else if (_shown.value < 1) {
      _shown.forward(); // arriving, or a copy joining part-way in
    }
  }

  /// Slide down into the edge, from wherever it has got to, then take the
  /// carrier away. Called through [_ToastHandle.leave], for every copy.
  void _leave() {
    if (!mounted) return;
    if (_reduceMotion) {
      AppToast._gone(widget.handle);
      return;
    }
    _shown.reverse().whenComplete(() {
      if (mounted) AppToast._gone(widget.handle);
    });
  }

  @override
  void dispose() {
    widget.handle._detach(this);
    _curve.dispose();
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The container and the gap under it move as one, by their own height:
    // at 0 the whole of it is below the carrier's bottom edge, clipped away.
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(0, 1 - _curve.value),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppToast._gap),
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
                  onPressed: widget.handle.leave,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../shared/app_colors.dart';

/// A direction pad for turning a camera: hold a button to keep moving, let go
/// to stop. Optical zoom is offered only when the camera has one.
///
/// The pad doesn't talk to the camera; it reports "started moving X" and
/// "let go". Buttons react to the raw pointer (not a tap) so a hold is felt
/// the instant the finger lands.
class PtzPad extends StatelessWidget {
  const PtzPad({
    super.key,
    required this.onStart,
    required this.onStop,
    this.zoom = false,
    this.compact = false,
    this.onDark = false,
  });

  /// [action] is one of up, down, left, right, zoom_in, zoom_out.
  final void Function(String action) onStart;
  final VoidCallback onStop;
  final bool zoom;

  /// A smaller pad, for laying over the picture in full screen.
  final bool compact;

  /// Light-on-dark colours (over the video).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = compact ? 132.0 : 176.0;
    final btn = compact ? 44.0 : 56.0;

    final pad = SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // The ring behind the arrows.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onDark ? Colors.black45 : Colors.white,
                border: Border.all(
                  color: onDark ? Colors.white24 : AppColors.cardBorder,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _HoldButton(
              id: 'up',
              label: l10n.camPtzUp,
              icon: Icons.keyboard_arrow_up_rounded,
              size: btn,
              onDark: onDark,
              onStart: onStart,
              onStop: onStop,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _HoldButton(
              id: 'down',
              label: l10n.camPtzDown,
              icon: Icons.keyboard_arrow_down_rounded,
              size: btn,
              onDark: onDark,
              onStart: onStart,
              onStop: onStop,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _HoldButton(
              id: 'left',
              label: l10n.camPtzLeft,
              icon: Icons.keyboard_arrow_left_rounded,
              size: btn,
              onDark: onDark,
              onStart: onStart,
              onStop: onStop,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _HoldButton(
              id: 'right',
              label: l10n.camPtzRight,
              icon: Icons.keyboard_arrow_right_rounded,
              size: btn,
              onDark: onDark,
              onStart: onStart,
              onStop: onStop,
            ),
          ),
          Center(
            child: Container(
              width: btn * 0.7,
              height: btn * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onDark ? Colors.white12 : AppColors.bgSoft,
              ),
              child: Icon(
                Icons.open_with_rounded,
                size: btn * 0.38,
                color: onDark ? Colors.white70 : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );

    if (!zoom) return pad;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pad,
        SizedBox(width: compact ? 12 : 20),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HoldButton(
              id: 'zoom_in',
              label: l10n.camZoomIn,
              icon: Icons.add_rounded,
              size: btn,
              round: true,
              onDark: onDark,
              onStart: onStart,
              onStop: onStop,
            ),
            SizedBox(height: compact ? 10 : 16),
            _HoldButton(
              id: 'zoom_out',
              label: l10n.camZoomOut,
              icon: Icons.remove_rounded,
              size: btn,
              round: true,
              onDark: onDark,
              onStart: onStart,
              onStop: onStop,
            ),
          ],
        ),
      ],
    );
  }
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
    required this.id,
    required this.label,
    required this.icon,
    required this.size,
    required this.onStart,
    required this.onStop,
    this.round = false,
    this.onDark = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final double size;
  final bool round;
  final bool onDark;
  final void Function(String action) onStart;
  final VoidCallback onStop;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  bool _down = false;

  void _press() {
    if (_down) return;
    setState(() => _down = true);
    HapticFeedback.selectionClick();
    widget.onStart(widget.id);
  }

  void _release() {
    // A finger lifted after the button is gone (the screen was left) still
    // reaches us through the pointer route; there is nothing left to do.
    if (!mounted || !_down) return;
    setState(() => _down = false);
    widget.onStop();
  }

  @override
  void dispose() {
    // Never leave the camera moving because the button went away mid-hold.
    if (_down) widget.onStop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idle = widget.onDark ? Colors.white : AppColors.deepNavy;
    return Semantics(
      button: true,
      label: widget.label,
      child: Listener(
        key: ValueKey('ptz-${widget.id}'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _down
                ? AppColors.softBlue
                : (widget.round
                      ? (widget.onDark ? Colors.black45 : Colors.white)
                      : Colors.transparent),
            border: widget.round
                ? Border.all(
                    color: widget.onDark
                        ? Colors.white24
                        : AppColors.cardBorder,
                  )
                : null,
          ),
          child: Icon(
            widget.icon,
            size: widget.size * 0.62,
            color: _down ? Colors.white : idle,
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/appliance.dart';
import 'appliance_status.dart';

/// The card every drawn appliance stands in: a room whose colours follow the
/// appliance, the drawing itself ([scene]), the big power button, and, while
/// the appliance can't be reached, a veil that says so.
class ApplianceHeroFrame extends StatelessWidget {
  const ApplianceHeroFrame({
    super.key,
    required this.label,
    required this.top,
    required this.bottom,
    required this.buttonAccent,
    required this.scene,
    required this.on,
    required this.enabled,
    required this.onPower,
    this.offline = false,
  });

  /// What a screen reader says about it.
  final String label;

  /// The room's colours, top and bottom.
  final Color top;
  final Color bottom;

  /// The power symbol's colour while on.
  final Color buttonAccent;
  final Widget scene;
  final bool on;

  /// Whether the power button can be pressed.
  final bool enabled;
  final ValueChanged<bool> onPower;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: label,
      child: AspectRatio(
        aspectRatio: 1.2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, bottom],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                scene,
                if (offline) const _OfflineVeil(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Center(
                    child: HeroPowerButton(
                      on: on,
                      accent: buttonAccent,
                      onPressed: enabled
                          ? () {
                              HapticFeedback.mediumImpact();
                              onPower(!on);
                            }
                          : null,
                    ),
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

/// Over the drawing while the appliance can't be reached: it greys out, and
/// says so in words.
class _OfflineVeil extends StatelessWidget {
  const _OfflineVeil();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F4FA).withValues(alpha: .55),
      child: Align(
        alignment: const Alignment(0, -0.92),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: StatusPill(
              look: StatusLook.forStatus(context.l10n, ApplianceStatus.offline),
              large: true,
            ),
          ),
        ),
      ),
    );
  }
}

class HeroPowerButton extends StatelessWidget {
  const HeroPowerButton({
    super.key,
    required this.on,
    required this.accent,
    required this.onPressed,
  });

  final bool on;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? Colors.white : const Color(0xFFF8FAFD),
      shape: const CircleBorder(),
      elevation: on ? 6 : 2,
      shadowColor: Colors.black54,
      // Presses show inside the circle: without this the pressed colour is
      // painted over the button's whole 60 x 60 box, corners and all.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 60,
          height: 60,
          child: Icon(
            Icons.power_settings_new_rounded,
            size: 30,
            color: onPressed == null
                ? Colors.black26
                : (on ? accent : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}

/// A drawing's running time. It ticks while [run] is told the appliance is
/// on, and once it is off it lets the last movement settle and then stands
/// still: a screen with nothing moving schedules no frames at all.
///
/// Subclasses move their own values on in [advance]; everything they keep
/// carries on from where it was, so a change of setting eases in.
class HeroClock extends ChangeNotifier {
  HeroClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Timer? _settle;

  /// Seconds it has been running, all told.
  double seconds = 0;

  bool get running => _ticker.isActive;

  void run(bool on) {
    _settle?.cancel();
    if (on) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _settle = Timer(const Duration(milliseconds: 750), _ticker.stop);
    }
  }

  /// Stops now, without letting anything settle: for when what moves has
  /// already come to rest by itself.
  void stop() {
    _settle?.cancel();
    if (_ticker.isActive) _ticker.stop();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    seconds += dt;
    advance(dt);
    notifyListeners();
  }

  /// Moves the subclass's own values on by [dt] seconds.
  @protected
  void advance(double dt) {}

  @override
  void dispose() {
    _settle?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}

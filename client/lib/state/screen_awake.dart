import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the phone's screen from turning itself off.
///
/// Watching a camera is passive: no touches, so the system's auto-lock would
/// switch the screen off mid-stream. An interface so tests (and platforms with
/// no plugin) don't need the real thing.
abstract class ScreenAwake {
  /// Holds the screen on (true) or lets it sleep again (false).
  Future<void> hold(bool on);
}

class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> hold(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // No plugin here (desktop/tests): the screen just behaves as usual.
    }
  }
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const WakelockScreenAwake(),
);

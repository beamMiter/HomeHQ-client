import 'package:flutter/services.dart';

/// Which way up the app is allowed to be.
///
/// Every screen is laid out for portrait, so portrait is where the app rests
/// and what it returns to. The only landscape is the camera's full screen,
/// asked for explicitly.
///
/// This used to hand orientation "back to the system" after full screen. That
/// let a phone that was merely tilted (or still held sideways) swing the whole
/// app into landscape the moment the camera page was left, and on iOS an empty
/// list does not turn a landscape screen upright anyway.
class AppOrientation {
  AppOrientation._();

  static const _portrait = [DeviceOrientation.portraitUp];

  /// The resting state. Call once at start-up.
  static void lockPortrait() {
    SystemChrome.setPreferredOrientations(_portrait);
  }

  /// Full screen: sideways, with the system bars out of the way.
  static void landscape() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Upright, with the system bars back. Asked for by name, so a landscape
  /// screen really does turn.
  static void portrait() {
    SystemChrome.setPreferredOrientations(_portrait);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

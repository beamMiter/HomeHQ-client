import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a point in the device's native maps app: Apple Maps on iOS/macOS,
/// Google Maps elsewhere. With [directions] it starts navigation to the point
/// instead of just showing it.
///
/// Plain https links are used on purpose. They open the installed app when
/// there is one and fall back to the browser, and unlike a `geo:` URI they
/// don't depend on `canLaunchUrl`, which Android 11+ answers "no" to without
/// manifest `<queries>`.
Future<bool> openInMaps({
  required double lat,
  required double lng,
  String? label,
  bool directions = false,
}) {
  final isApple =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  final name = (label == null || label.isEmpty)
      ? ''
      : '&q=${Uri.encodeComponent(label)}';

  final uri = isApple
      ? Uri.parse(
          directions
              ? 'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d'
              : 'https://maps.apple.com/?ll=$lat,$lng$name',
        )
      : Uri.parse(
          directions
              ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
              : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        );

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

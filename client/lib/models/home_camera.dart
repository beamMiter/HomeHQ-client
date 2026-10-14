/// One camera, as the server lists it.
class HomeCamera {
  const HomeCamera({
    required this.id,
    required this.name,
    this.model,
    this.online = false,
    this.humanDetect = false,
    this.ptz = false,
    this.zoom = false,
    this.switches = const [],
  });

  final String id;
  final String name;
  final String? model;

  /// Whether the camera's cloud can reach it right now.
  final bool online;

  /// The camera itself can tell a person from other movement.
  final bool humanDetect;

  /// The camera can be turned (pan/tilt), and has an optical zoom.
  final bool ptz;
  final bool zoom;

  /// On/off settings this camera has: 'privacy', 'motion', 'human'.
  final List<String> switches;

  factory HomeCamera.fromJson(Map<String, dynamic> j) => HomeCamera(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    model: j['model']?.toString(),
    online: j['online'] == true,
    humanDetect: j['human_detect'] == true,
    ptz: j['ptz'] == true,
    zoom: j['zoom'] == true,
    switches: [
      for (final s in (j['switches'] as List? ?? const [])) s.toString(),
    ],
  );
}

/// Where to play a camera from.
class CameraLive {
  const CameraLive({required this.url, this.protocol = 'hls', this.quality});

  final String url;
  final String protocol;

  /// 'hd' or 'sd'.
  final String? quality;

  factory CameraLive.fromJson(Map<String, dynamic> j) => CameraLive(
    url: (j['url'] ?? '').toString(),
    protocol: (j['protocol'] ?? 'hls').toString(),
    quality: j['quality']?.toString(),
  );
}

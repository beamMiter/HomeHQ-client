import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/home_camera.dart';
import '../repositories/cameras_repository.dart';
import '../services/api_client.dart' show apiClientProvider;

final camerasRepoProvider = Provider<CamerasRepository>(
  (ref) => CamerasRepository(ref.watch(apiClientProvider).dio),
);

/// Whether the server has a camera source, and how much of today's allowance
/// is used. Costs no camera-cloud call. Null when the server can't be asked.
final camerasStatusProvider = FutureProvider.autoDispose<CamerasStatus?>(
  (ref) => ref.watch(camerasRepoProvider).status(),
);

/// The cameras on the account.
class CamerasNotifier extends AsyncNotifier<List<HomeCamera>> {
  @override
  Future<List<HomeCamera>> build() => ref.watch(camerasRepoProvider).list();

  /// Asks the server for fresh data (skipping its cache) and drops the
  /// pictures already shown, so a manual refresh really is one.
  Future<void> reload() async {
    final repo = ref.read(camerasRepoProvider);
    final next = await AsyncValue.guard(() => repo.list(refresh: true));
    ref.invalidate(cameraSnapshotProvider);
    state = next;
    if (next.hasError) throw next.error!;
  }
}

final camerasProvider =
    AsyncNotifierProvider.autoDispose<CamerasNotifier, List<HomeCamera>>(
      CamerasNotifier.new,
    );

/// A still picture per camera. Kept for half a minute after the last listener
/// goes, so scrolling or a quick back-and-forth doesn't ask the camera again.
final cameraSnapshotProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, id) async {
      final link = ref.keepAlive();
      Timer? timer;
      ref.onCancel(() {
        timer = Timer(const Duration(seconds: 30), link.close);
      });
      ref.onResume(() => timer?.cancel());
      ref.onDispose(() => timer?.cancel());
      return ref.watch(camerasRepoProvider).snapshot(id);
    });

extension SnapshotFailure on AsyncValue<Uint8List> {
  /// The picture could not be fetched. A camera that simply has no still
  /// picture to give (the server says "not supported") is not a failure: it
  /// keeps a plain camera on its cover.
  bool get pictureFailed {
    final e = error;
    if (!hasError) return false;
    return !(e is CameraException && e.failure == CameraFailure.unsupported);
  }
}

/// The on/off settings of one camera (only the ones it supports).
///
/// One notifier per camera, shared by everything that shows or flips a
/// setting (the settings card, the light button over the picture), so they
/// can never disagree.
class CameraSwitchesNotifier extends AsyncNotifier<Map<String, bool>> {
  CameraSwitchesNotifier(this.id);
  final String id;

  @override
  Future<Map<String, bool>> build() =>
      ref.watch(camerasRepoProvider).switches(id);

  /// Shows [on] at once and sends it; undoes it and rethrows if it fails.
  Future<void> set(String key, bool on) async {
    final before = state.value;
    if (before != null) state = AsyncData({...before, key: on});
    try {
      await ref.read(camerasRepoProvider).setSwitch(id, key, on);
    } catch (_) {
      if (ref.mounted && before != null) state = AsyncData(before);
      rethrow;
    }
  }
}

final cameraSwitchesProvider = AsyncNotifierProvider.autoDispose
    .family<CameraSwitchesNotifier, Map<String, bool>, String>(
      CameraSwitchesNotifier.new,
    );

/// Where to play a camera from at the given quality ('hd' / 'sd').
typedef LiveKey = ({String id, String quality});

final cameraLiveProvider = FutureProvider.autoDispose
    .family<CameraLive, LiveKey>(
      (ref, key) =>
          ref.watch(camerasRepoProvider).live(key.id, quality: key.quality),
    );

/// How a player is made from an address. A provider so tests can swap in one
/// that doesn't need the platform plugin.
final videoControllerFactoryProvider =
    Provider<VideoPlayerController Function(Uri)>(
      (ref) =>
          (uri) => VideoPlayerController.networkUrl(uri),
    );

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/home_camera.dart';

/// Why a camera request did not work, in terms the screen can word.
enum CameraFailure {
  /// The server has no camera source configured (or predates /cameras).
  disabled,

  /// The server's camera account details were rejected.
  misconfigured,

  /// The camera cloud itself refused: its own call allowance is used up.
  /// (The app and server put no limit of their own on a household.)
  limited,

  /// The camera is offline.
  offline,

  /// The camera is not known to the account.
  notFound,

  /// This camera doesn't have that capability.
  unsupported,

  /// Network down, or the camera service answered with an error.
  unavailable,
}

class CameraException implements Exception {
  const CameraException(this.failure);
  final CameraFailure failure;

  @override
  String toString() => 'CameraException($failure)';
}

/// What the server says about cameras before we ask for any.
class CamerasStatus {
  const CamerasStatus({required this.enabled, this.driver});

  final bool enabled;
  final String? driver;
}

/// Talks to our own `/cameras` endpoints. The camera account lives on the
/// server; the app never sees it, nor any camera password.
class CamerasRepository {
  CamerasRepository(this._dio);
  final Dio _dio;

  Future<CamerasStatus?> status() async {
    try {
      final resp = await _dio.get('/cameras/status');
      final b = resp.data;
      if (b is! Map) return null;
      return CamerasStatus(
        enabled: b['enabled'] == true,
        driver: b['driver']?.toString(),
      );
    } on DioException catch (e) {
      // An older server has no /cameras at all: the same as "not set up".
      if (e.response?.statusCode == 404) {
        return const CamerasStatus(enabled: false);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// [refresh] asks the server to skip its short-lived cache.
  Future<List<HomeCamera>> list({bool refresh = false}) async {
    try {
      final resp = await _dio.get(
        '/cameras',
        queryParameters: {if (refresh) 'refresh': 1},
      );
      final raw = resp.data is Map ? (resp.data as Map)['items'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => HomeCamera.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  Future<CameraLive> live(String id, {String quality = 'hd'}) async {
    try {
      final resp = await _dio.get(
        '/cameras/${Uri.encodeComponent(id)}/live',
        queryParameters: {'quality': quality},
      );
      final b = resp.data;
      if (b is! Map) throw const CameraException(CameraFailure.unavailable);
      final live = CameraLive.fromJson(b.cast<String, dynamic>());
      if (live.url.isEmpty) {
        throw const CameraException(CameraFailure.unavailable);
      }
      return live;
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// Turns the camera head. [action] is one of up, down, left, right,
  /// up_left, up_right, down_left, down_right, zoom_in, zoom_out, stop.
  Future<void> ptz(String id, String action, {int? durationMs}) async {
    try {
      await _dio.post(
        '/cameras/${Uri.encodeComponent(id)}/ptz',
        data: {'action': action, 'duration_ms': ?durationMs},
      );
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// Current state of each setting the camera supports.
  Future<Map<String, bool>> switches(String id) async {
    try {
      final resp = await _dio.get(
        '/cameras/${Uri.encodeComponent(id)}/switches',
      );
      final b = resp.data;
      if (b is! Map) return const {};
      return {for (final e in b.entries) e.key.toString(): e.value == true};
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  Future<void> setSwitch(String id, String key, bool on) async {
    try {
      await _dio.put(
        '/cameras/${Uri.encodeComponent(id)}/switches/${Uri.encodeComponent(key)}',
        data: {'on': on},
      );
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  Future<Uint8List> snapshot(String id) async {
    try {
      final resp = await _dio.get<List<int>>(
        '/cameras/${Uri.encodeComponent(id)}/snapshot',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = resp.data;
      if (data == null || data.isEmpty) {
        throw const CameraException(CameraFailure.unavailable);
      }
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  CameraException _failure(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final code = data is Map ? data['error']?.toString() : null;

    if (status == 404 && code != 'camera_not_found') {
      // No such route: an older server.
      return const CameraException(CameraFailure.disabled);
    }
    return switch ((status, code)) {
      (503, 'cameras_disabled') => const CameraException(
        CameraFailure.disabled,
      ),
      (503, 'cameras_misconfigured') => const CameraException(
        CameraFailure.misconfigured,
      ),
      // Imou's own allowance ('provider_limit'); any other 429 means the same
      // to the person looking at the screen.
      (429, _) => const CameraException(CameraFailure.limited),
      (409, 'camera_offline') => const CameraException(CameraFailure.offline),
      (422, 'not_supported') => const CameraException(
        CameraFailure.unsupported,
      ),
      (404, _) => const CameraException(CameraFailure.notFound),
      _ => const CameraException(CameraFailure.unavailable),
    };
  }
}

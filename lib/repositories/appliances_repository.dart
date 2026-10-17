import 'package:dio/dio.dart';

import '../models/appliance.dart';

/// Why an appliance request did not work, in terms the screen can word.
enum ApplianceFailure {
  /// The server has no appliance source configured (or predates /appliances).
  disabled,

  /// The server's appliance account details were rejected.
  misconfigured,

  /// The vendor itself refused: its own call allowance is used up.
  limited,

  /// The appliance is offline.
  offline,

  /// The appliance is not known to the account.
  notFound,

  /// This appliance doesn't have that capability.
  unsupported,

  /// The control is for admins only.
  forbidden,

  /// The server did not accept the value.
  invalid,

  /// Network down, or the appliance service answered with an error.
  unavailable,
}

class ApplianceException implements Exception {
  const ApplianceException(this.failure);
  final ApplianceFailure failure;

  @override
  String toString() => 'ApplianceException($failure)';
}

/// What the server says about appliances before we ask for any.
class AppliancesStatus {
  const AppliancesStatus({
    required this.enabled,
    this.driver,
    this.canAdd = false,
  });

  final bool enabled;
  final String? driver;

  /// The household can add and remove appliances itself (the server's driver
  /// keeps its own list).
  final bool canAdd;
}

/// What a command answered with: the appliance's state, read back from it.
class ApplianceCommandResult {
  const ApplianceCommandResult({required this.state, this.confirmed = true});

  final Map<String, Object?> state;

  /// False when the command went through but the state could not be read
  /// back, so [state] is only what was asked for.
  final bool confirmed;
}

/// Talks to our own `/appliances` endpoints. The vendor account lives on the
/// server; the app never sees it.
class AppliancesRepository {
  AppliancesRepository(this._dio);
  final Dio _dio;

  Future<AppliancesStatus?> status() async {
    try {
      final resp = await _dio.get('/appliances/status');
      final b = resp.data;
      if (b is! Map) return null;
      return AppliancesStatus(
        enabled: b['enabled'] == true,
        driver: b['driver']?.toString(),
        canAdd: b['can_add'] == true,
      );
    } on DioException catch (e) {
      // An older server has no /appliances at all: the same as "not set up".
      if (e.response?.statusCode == 404) {
        return const AppliancesStatus(enabled: false);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// [refresh] asks the server to skip its short-lived cache.
  Future<List<Appliance>> list({bool refresh = false}) async {
    try {
      final resp = await _dio.get(
        '/appliances',
        queryParameters: {if (refresh) 'refresh': 1},
      );
      final raw = resp.data is Map ? (resp.data as Map)['items'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Appliance.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// Sets one capability. [value] is a bool, an int or a string, matching the
  /// capability's type.
  Future<ApplianceCommandResult> command(
    String id,
    String capability,
    Object value,
  ) async {
    try {
      final resp = await _dio.post(
        '/appliances/${Uri.encodeComponent(id)}/command',
        data: {'capability': capability, 'value': value},
      );
      final b = resp.data;
      if (b is! Map) {
        throw const ApplianceException(ApplianceFailure.unavailable);
      }
      final st = b['state'];
      return ApplianceCommandResult(
        state: st is Map
            ? {for (final e in st.entries) e.key.toString(): e.value}
            : {capability: value},
        confirmed: b['confirmed'] != false,
      );
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// Registers a new appliance (an admin action).
  Future<Appliance> add({
    required String name,
    required String kind,
    String? room,
    String? brand,
    String? model,
    String connection = 'demo',
  }) async {
    try {
      final resp = await _dio.post(
        '/appliances',
        data: {
          'name': name,
          'kind': kind,
          'room': ?room,
          'brand': ?brand,
          'model': ?model,
          'connection': connection,
        },
      );
      final b = resp.data;
      if (b is! Map) {
        throw const ApplianceException(ApplianceFailure.unavailable);
      }
      return Appliance.fromJson(b.cast<String, dynamic>());
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// Forgets an appliance the household added (an admin action).
  Future<void> remove(String id) async {
    try {
      await _dio.delete('/appliances/${Uri.encodeComponent(id)}');
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// Who sent what to this appliance, newest first.
  Future<List<ApplianceEvent>> events(String id, {int limit = 10}) async {
    try {
      final resp = await _dio.get(
        '/appliances/${Uri.encodeComponent(id)}/events',
        queryParameters: {'limit': limit},
      );
      final raw = resp.data is Map ? (resp.data as Map)['items'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ApplianceEvent.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  ApplianceException _failure(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final code = data is Map ? data['error']?.toString() : null;

    if (status == 404 && code != 'appliance_not_found') {
      // No such route: an older server.
      return const ApplianceException(ApplianceFailure.disabled);
    }
    return switch ((status, code)) {
      (503, 'appliances_disabled') => const ApplianceException(
        ApplianceFailure.disabled,
      ),
      (503, 'appliances_misconfigured') => const ApplianceException(
        ApplianceFailure.misconfigured,
      ),
      // The vendor's own allowance ('provider_limit'); any other 429 means
      // the same to the person looking at the screen.
      (429, _) => const ApplianceException(ApplianceFailure.limited),
      (409, 'appliance_offline') => const ApplianceException(
        ApplianceFailure.offline,
      ),
      (422, 'not_supported') => const ApplianceException(
        ApplianceFailure.unsupported,
      ),
      (403, 'admin_only') => const ApplianceException(
        ApplianceFailure.forbidden,
      ),
      (400, _) => const ApplianceException(ApplianceFailure.invalid),
      (404, _) => const ApplianceException(ApplianceFailure.notFound),
      _ => const ApplianceException(ApplianceFailure.unavailable),
    };
  }
}

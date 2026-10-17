import 'package:dio/dio.dart';

import '../models/spending.dart';

/// Why the dashboard could not be read, in terms the screen can word.
enum DashboardFailure {
  /// The server predates the dashboard.
  unsupported,

  /// Network down, or the server answered with an error.
  unavailable,
}

class DashboardException implements Exception {
  const DashboardException(this.failure);
  final DashboardFailure failure;

  @override
  String toString() => 'DashboardException($failure)';
}

/// Talks to `/dashboard/spending`.
class DashboardRepository {
  DashboardRepository(this._dio);
  final Dio _dio;

  /// [month] is "YYYY-MM"; null means the current month.
  Future<Spending> spending({String? month}) async {
    try {
      final resp = await _dio.get(
        '/dashboard/spending',
        queryParameters: {if (month != null) 'month': month},
      );
      final b = resp.data;
      if (b is! Map) {
        throw const DashboardException(DashboardFailure.unavailable);
      }
      return Spending.fromJson(b.cast<String, dynamic>());
    } on DioException catch (e) {
      throw DashboardException(
        e.response?.statusCode == 404
            ? DashboardFailure.unsupported
            : DashboardFailure.unavailable,
      );
    }
  }
}

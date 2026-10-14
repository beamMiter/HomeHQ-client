import 'package:dio/dio.dart';
import '../models/contractor.dart';

class ContractorsRepository {
  final Dio _dio;
  ContractorsRepository(this._dio);

  Future<List<Contractor>> search({
    required double lat,
    required double lng,
    int radius = 3000,
    String? type,
    String? q,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    // Leading slash matters: the shared Dio's baseUrl has no trailing slash.
    final resp = await _dio.get(
      '/contractors/search',
      cancelToken: cancelToken,
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'limit': limit,
        if (type != null && type.isNotEmpty) 'type': type,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    return _parse(resp.data);
  }

  /// The household's starred contractors, wherever they are: the people you
  /// trust don't stop being useful because they are across town.
  Future<List<Contractor>> favorites({CancelToken? cancelToken}) async {
    final resp = await _dio.get(
      '/contractors/favorites',
      cancelToken: cancelToken,
    );
    return _parse(resp.data);
  }

  /// Flips the star and returns the state the server ended up with.
  Future<bool> toggleFavorite(String id) async {
    final resp = await _dio.post(
      '/contractors/${Uri.encodeComponent(id)}/favorite',
    );
    final body = resp.data;
    return body is Map && body['is_favorite'] == true;
  }

  /// The API wraps lists as {data: [...], items: [...], paging: {...}}.
  List<Contractor> _parse(Object? body) {
    final raw = body is List
        ? body
        : (body is Map ? (body['items'] ?? body['data']) : null);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Contractor.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

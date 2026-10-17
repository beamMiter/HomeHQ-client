import 'package:dio/dio.dart';

import '../models/contractor.dart';

/// Whether Google results are available right now.
enum GoogleStatus {
  /// The server has no Google key configured (or predates /places). Nothing to
  /// show, nothing wrong.
  off,

  /// Results came back (possibly an empty list).
  ok,

  /// Today's call allowance on the server is used up.
  limited,

  /// This user is searching too fast; try again in a moment.
  busy,

  /// Configured but not answering: network, upstream error.
  unavailable,
}

class GoogleNearby {
  const GoogleNearby(this.items, this.status, {this.skipped = 0});
  const GoogleNearby.off() : this(const [], GoogleStatus.off);
  const GoogleNearby.unavailable() : this(const [], GoogleStatus.unavailable);

  final List<Contractor> items;
  final GoogleStatus status;

  /// Starred places Google could no longer return (closed, id retired).
  final int skipped;
}

/// What the server says about Google before we search.
class PlacesServerStatus {
  const PlacesServerStatus({
    required this.enabled,
    this.dailyUsed = 0,
    this.dailyLimit = 0,
  });

  final bool enabled;
  final int dailyUsed;

  /// 0 = no daily limit.
  final int dailyLimit;

  int? get dailyRemaining =>
      dailyLimit <= 0 ? null : (dailyLimit - dailyUsed).clamp(0, dailyLimit);
}

/// Talks to our own `/places` endpoints. The server holds the Google key; the
/// app never sees it.
///
/// Searching never throws for Google trouble: the saved contractors must keep
/// working when Google is off, rate limited or down.
class PlacesRepository {
  PlacesRepository(this._dio, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _now;

  /// How long an identical search is answered from memory. Short on purpose:
  /// it exists to absorb "ช่างไฟ → ทั้งหมด → ช่างไฟ", not to keep Google's data
  /// around (their terms only allow caching coordinates and place ids).
  /// Set to [Duration.zero] to disable.
  static const memoTtl = Duration(minutes: 2);

  final Map<String, ({DateTime at, GoogleNearby value})> _memo = {};

  /// Forgets remembered searches. A manual refresh must reach the server
  /// instead of being answered from the last two minutes.
  void clearMemo() => _memo.clear();

  Future<PlacesServerStatus?> status() async {
    try {
      final resp = await _dio.get('/places/status');
      final b = resp.data;
      if (b is! Map) return null;
      return PlacesServerStatus(
        enabled: b['enabled'] == true,
        dailyUsed: (b['daily_used'] as num?)?.toInt() ?? 0,
        dailyLimit: (b['daily_limit'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      // An older server has no /places at all: same as "not enabled".
      if (e.response?.statusCode == 404) {
        return const PlacesServerStatus(enabled: false);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<GoogleNearby> nearby({
    required double lat,
    required double lng,
    int radius = 3000,
    String? type,
    String? q,
    int? limit,
    CancelToken? cancelToken,
  }) async {
    final key = _memoKey(lat, lng, radius, type, q, limit);
    final hit = _memo[key];
    if (hit != null && _now().difference(hit.at) < memoTtl) return hit.value;

    try {
      final resp = await _dio.get(
        '/places/nearby',
        cancelToken: cancelToken,
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': radius,
          if (type != null && type.isNotEmpty) 'type': type,
          if (q != null && q.isNotEmpty) 'q': q,
          if (limit != null) 'limit': limit,
        },
      );
      final result = GoogleNearby(_items(resp.data), GoogleStatus.ok);
      _memo[key] = (at: _now(), value: result);
      _trimMemo();
      return result;
    } on DioException catch (e) {
      return GoogleNearby([], _statusFor(e));
    } catch (_) {
      return const GoogleNearby.unavailable();
    }
  }

  /// The places the household has starred (looked up from Google by id).
  Future<GoogleNearby> starred({
    required double lat,
    required double lng,
    CancelToken? cancelToken,
  }) async {
    try {
      final resp = await _dio.get(
        '/places/starred',
        cancelToken: cancelToken,
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final body = resp.data;
      final skipped = body is Map ? (body['skipped'] as num?)?.toInt() ?? 0 : 0;
      return GoogleNearby(_items(body), GoogleStatus.ok, skipped: skipped);
    } on DioException catch (e) {
      return GoogleNearby([], _statusFor(e));
    } catch (_) {
      return const GoogleNearby.unavailable();
    }
  }

  /// Phone, rating, website and opening status for one Google place, or null.
  Future<PlaceDetails?> details(String placeId) async {
    try {
      final resp = await _dio.get('/places/${Uri.encodeComponent(placeId)}');
      final body = resp.data;
      if (body is! Map) return null;
      return PlaceDetails.fromJson(body.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  /// Stars or unstars a Google place. Throws on failure so the caller can undo
  /// its optimistic update. Only the place id (and our trade label) is stored.
  Future<void> setStar(
    String placeId, {
    required bool on,
    String? trade,
  }) async {
    final path = '/places/${Uri.encodeComponent(placeId)}/star';
    if (on) {
      await _dio.put(
        path,
        data: {if (trade != null && trade.isNotEmpty) 'trade': trade},
      );
    } else {
      await _dio.delete(path);
    }
  }

  // ── internals ─────────────────────────────────────────────────────────────

  List<Contractor> _items(Object? body) {
    final raw = body is Map ? body['items'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Contractor.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  GoogleStatus _statusFor(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final code = data is Map ? data['error'] : null;

    // Not configured on the server, or an older server that predates /places:
    // both mean "this feature isn't here", which is not a fault to report.
    if ((status == 503 && code == 'google_places_disabled') || status == 404) {
      return GoogleStatus.off;
    }
    if (status == 429) {
      return code == 'daily_limit' ? GoogleStatus.limited : GoogleStatus.busy;
    }
    return GoogleStatus.unavailable;
  }

  // ~100 m grid so a GPS wobble reuses the answer; radius/type/q exact.
  String _memoKey(
    double lat,
    double lng,
    int radius,
    String? type,
    String? q,
    int? limit,
  ) =>
      '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}|$radius|'
      '${type ?? ''}|${(q ?? '').toLowerCase()}|${limit ?? ''}';

  void _trimMemo() {
    if (_memo.length <= 24) return;
    final cutoff = _now().subtract(memoTtl);
    _memo.removeWhere((_, v) => v.at.isBefore(cutoff));
    while (_memo.length > 24) {
      _memo.remove(_memo.keys.first);
    }
  }
}

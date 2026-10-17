import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homehq/models/contractor.dart';
import 'package:homehq/repositories/places_repository.dart';
import 'package:homehq/state/contractors_provider.dart';

Contractor _saved(String name, double lat, double lng) => Contractor(
  id: 'saved-$name',
  name: name,
  types: const ['electrician'],
  lat: lat,
  lng: lng,
);

Contractor _google(String name, double lat, double lng, {String? id}) =>
    Contractor(
      id: 'google:${id ?? name}',
      name: name,
      types: const ['electrician'],
      lat: lat,
      lng: lng,
      source: ContractorSource.google,
      placeId: id ?? name,
    );

/// A Dio whose "network" is a function.
Dio _dio(ResponseBody Function(RequestOptions o) handler) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://test.local/api/v1',
      // Same as the app's shared client: anything >= 400 throws.
      validateStatus: (c) => c != null && c >= 200 && c < 400,
    ),
  );
  dio.httpClientAdapter = _Stub(handler);
  return dio;
}

class _Stub implements HttpClientAdapter {
  _Stub(this.handler);
  final ResponseBody Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  group('Contractor.fromJson', () {
    test('a Google result keeps its place id and link', () {
      final c = Contractor.fromJson({
        'id': 'google:ChIJabc',
        'place_id': 'ChIJabc',
        'source': 'google',
        'name': 'ช่างอ้น',
        'types': ['electrician'],
        'lat': 13.75,
        'lng': 100.53,
        'distance_m': 420.5,
        'maps_url': 'https://www.google.com/maps/search/?api=1&query=x',
      });
      expect(c.isGoogle, isTrue);
      expect(c.placeId, 'ChIJabc');
      expect(c.mapsUrl, contains('google.com/maps'));
    });

    test('a saved contractor is not mistaken for a Google one', () {
      final c = Contractor.fromJson({
        'id': 'uuid-1',
        'name': 'ช่างประปาแถวบ้าน',
        'types': ['plumber'],
        'google_maps_url': 'https://maps.example/x',
      });
      expect(c.isGoogle, isFalse);
      expect(c.placeId, isNull);
      expect(c.mapsUrl, 'https://maps.example/x');
    });
  });

  group('PlaceDetails', () {
    test('falls back to the international number', () {
      final d = PlaceDetails.fromJson({
        'phone': '  ',
        'international_phone': '+66 81 234 5678',
        'rating': 4.5,
        'rating_count': 120,
        'open_now': false,
      });
      expect(d.phone, '+66 81 234 5678');
      expect(d.rating, 4.5);
      expect(d.ratingCount, 120);
      expect(d.openNow, isFalse);
    });

    test('withDetails fills a Google result without touching its place', () {
      final base = _google('ช่างอ้น', 13.75, 100.53, id: 'ChIJabc');
      final merged = base.withDetails(
        const PlaceDetails(phone: '081', rating: 4.2, openNow: true),
      );
      expect(merged.phone, '081');
      expect(merged.rating, 4.2);
      expect(merged.openNow, isTrue);
      expect(merged.placeId, 'ChIJabc');
      expect(merged.position, base.position);
    });
  });

  group('mergeSavedAndGoogle', () {
    test('drops the Google twin of a saved contractor', () {
      final out = mergeSavedAndGoogle(
        [_saved('ช่างอ้น', 13.7512, 100.5410)],
        [_google('ช่างอ้น (ร้านช่างไฟ)', 13.7513, 100.5411)],
      );
      expect(out.map((c) => c.id), ['saved-ช่างอ้น']);
    });

    test('keeps a Google shop with a different name even if adjacent', () {
      final out = mergeSavedAndGoogle(
        [_saved('ช่างอ้น', 13.7512, 100.5410)],
        [_google('ร้านไฟฟ้าสยาม', 13.7512, 100.5410)],
      );
      expect(out, hasLength(2));
    });

    test('keeps a same-named shop that is far away', () {
      final out = mergeSavedAndGoogle(
        [_saved('ช่างอ้น', 13.7512, 100.5410)],
        [_google('ช่างอ้น', 13.80, 100.60)], // several km off
      );
      expect(out, hasLength(2));
    });

    test('ignores spacing and punctuation when comparing names', () {
      final out = mergeSavedAndGoogle(
        [_saved('ช่าง อ้น', 13.7512, 100.5410)],
        [_google('ช่าง-อ้น.', 13.7512, 100.5410)],
      );
      expect(out, hasLength(1));
    });

    test('a saved contractor with no coordinates never hides a Google one', () {
      final out = mergeSavedAndGoogle(
        [Contractor(id: 's', name: 'ช่างอ้น', types: const [])],
        [_google('ช่างอ้น', 13.7512, 100.5410)],
      );
      expect(out, hasLength(2));
    });
  });

  group('PlacesRepository.nearby', () {
    test('parses results and reports ok', () async {
      late RequestOptions seen;
      final repo = PlacesRepository(
        _dio((o) {
          seen = o;
          return _json({
            'source': 'google',
            'items': [
              {
                'id': 'google:ChIJ1',
                'place_id': 'ChIJ1',
                'source': 'google',
                'name': 'ช่างอ้น',
                'types': ['electrician'],
                'lat': 13.75,
                'lng': 100.53,
                'distance_m': 300,
                'maps_url': 'https://www.google.com/maps/search/?api=1&query=x',
              },
            ],
          });
        }),
      );

      final r = await repo.nearby(
        lat: 13.7455,
        lng: 100.5342,
        radius: 3000,
        type: 'electrician',
        q: 'ช่างไฟ',
      );

      expect(seen.path, '/places/nearby');
      expect(seen.queryParameters['type'], 'electrician');
      expect(seen.queryParameters['radius'], 3000);
      expect(r.status, GoogleStatus.ok);
      expect(r.items.single.isGoogle, isTrue);
    });

    test(
      '503 google_places_disabled reads as "off", not as an error',
      () async {
        final repo = PlacesRepository(
          _dio((_) => _json({'error': 'google_places_disabled'}, 503)),
        );
        final r = await repo.nearby(lat: 1, lng: 1);
        expect(r.status, GoogleStatus.off);
        expect(r.items, isEmpty);
      },
    );

    test('an older server without /places reads as "off"', () async {
      final repo = PlacesRepository(_dio((_) => _json({'error': 'x'}, 404)));
      final r = await repo.nearby(lat: 1, lng: 1);
      expect(r.status, GoogleStatus.off);
    });

    test('a failing Google is "unavailable" and never throws', () async {
      for (final status in [500, 502, 504]) {
        final repo = PlacesRepository(
          _dio((_) => _json({'error': 'google_places_unavailable'}, status)),
        );
        final r = await repo.nearby(lat: 1, lng: 1);
        expect(r.status, GoogleStatus.unavailable, reason: 'status $status');
      }
    });

    test('429 says which limit was hit', () async {
      final daily = PlacesRepository(
        _dio((_) => _json({'error': 'daily_limit'}, 429)),
      );
      expect((await daily.nearby(lat: 1, lng: 1)).status, GoogleStatus.limited);

      final rate = PlacesRepository(
        _dio((_) => _json({'error': 'rate_limited'}, 429)),
      );
      expect((await rate.nearby(lat: 1, lng: 1)).status, GoogleStatus.busy);
    });

    test('a dead network is "unavailable" and never throws', () async {
      final repo = PlacesRepository(
        _dio(
          (o) => throw DioException.connectionError(
            requestOptions: o,
            reason: 'offline',
          ),
        ),
      );
      final r = await repo.nearby(lat: 1, lng: 1);
      expect(r.status, GoogleStatus.unavailable);
    });

    test('a malformed body is treated as no results', () async {
      final repo = PlacesRepository(_dio((_) => _json({'items': 'nope'})));
      final r = await repo.nearby(lat: 1, lng: 1);
      expect(r.status, GoogleStatus.ok);
      expect(r.items, isEmpty);
    });
  });

  group('PlacesRepository.details', () {
    test('returns phone and rating', () async {
      late RequestOptions seen;
      final repo = PlacesRepository(
        _dio((o) {
          seen = o;
          return _json({
            'place_id': 'ChIJ1',
            'phone': '081 234 5678',
            'rating': 4.7,
            'rating_count': 33,
            'open_now': true,
          });
        }),
      );
      final d = await repo.details('ChIJ1');
      expect(seen.path, '/places/ChIJ1');
      expect(d?.phone, '081 234 5678');
      expect(d?.rating, 4.7);
      expect(d?.openNow, isTrue);
    });

    test('any failure is null, not an exception', () async {
      final repo = PlacesRepository(_dio((_) => _json({'error': 'x'}, 502)));
      expect(await repo.details('ChIJ1'), isNull);
    });
  });
}

// Tests for the logic that decides what a search costs: which calls are made,
// when, and around where. This is the part that protects the Google bill.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:homeservice/models/contractor.dart';
import 'package:homeservice/repositories/contractors_repository.dart';
import 'package:homeservice/repositories/places_repository.dart';
import 'package:homeservice/state/contractors_provider.dart';
import 'package:homeservice/state/location_controller.dart';

class _Loc extends LocationController {
  _Loc(this._at);
  final LocationState _at;
  @override
  LocationState build() => _at;
  @override
  Future<void> refresh() async {}
}

const _siam = LocationState(
  location: UserLocation(
    lat: 13.7455,
    lng: 100.5342,
    source: LocationSource.currentFix,
  ),
);

class _Call {
  _Call(this.name, this.args);
  final String name;
  final Map<String, Object?> args;
  @override
  String toString() => '$name($args)';
}

class _Saved extends ContractorsRepository {
  _Saved(this.calls, {this.items = const []}) : super(Dio());
  final List<_Call> calls;
  final List<Contractor> items;

  @override
  Future<List<Contractor>> search({
    required double lat,
    required double lng,
    int radius = 3000,
    String? type,
    String? q,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    calls.add(
      _Call('saved.search', {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'type': type,
        'q': q,
      }),
    );
    return items;
  }

  @override
  Future<List<Contractor>> favorites({CancelToken? cancelToken}) async {
    calls.add(_Call('saved.favorites', {}));
    return items;
  }
}

class _Places extends PlacesRepository {
  _Places(
    this.calls, {
    this.server = const PlacesServerStatus(enabled: true),
    this.result = const GoogleNearby([], GoogleStatus.ok),
  }) : super(Dio());

  final List<_Call> calls;
  final PlacesServerStatus? server;
  final GoogleNearby result;

  @override
  Future<PlacesServerStatus?> status() async => server;

  @override
  Future<GoogleNearby> nearby({
    required double lat,
    required double lng,
    int radius = 3000,
    String? type,
    String? q,
    int? limit,
    CancelToken? cancelToken,
  }) async {
    calls.add(
      _Call('google.nearby', {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'type': type,
        'q': q,
      }),
    );
    return result;
  }

  @override
  Future<GoogleNearby> starred({
    required double lat,
    required double lng,
    CancelToken? cancelToken,
  }) async {
    calls.add(_Call('google.starred', {'lat': lat, 'lng': lng}));
    return result;
  }
}

ProviderContainer _container({
  required List<_Call> calls,
  _Saved? saved,
  _Places? places,
  LocationState loc = _siam,
}) {
  final c = ProviderContainer(
    overrides: [
      locationControllerProvider.overrideWith(() => _Loc(loc)),
      contractorsRepoProvider.overrideWithValue(saved ?? _Saved(calls)),
      placesRepoProvider.overrideWithValue(places ?? _Places(calls)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

List<String> _names(List<_Call> calls) => calls.map((c) => c.name).toList();

void main() {
  group('what a search costs', () {
    test('browsing "all" asks Google nothing', () async {
      final calls = <_Call>[];
      final c = _container(calls: calls);

      await c.read(contractorsListProvider.future);

      expect(_names(calls), ['saved.search']);
    });

    test('picking a trade makes exactly one Google call', () async {
      final calls = <_Call>[];
      final c = _container(calls: calls);
      c.read(contractorFilterProvider.notifier).setType('plumber');

      await c.read(contractorsListProvider.future);

      expect(_names(calls), containsAll(['saved.search', 'google.nearby']));
      final google = calls.singleWhere((x) => x.name == 'google.nearby');
      expect(google.args['type'], 'plumber');
      expect(google.args['radius'], 3000); // starts small
    });

    test('typing a search asks Google with the text', () async {
      final calls = <_Call>[];
      final c = _container(calls: calls);
      c.read(contractorFilterProvider.notifier).setQuery('ซ่อมท่อ');

      await c.read(contractorsListProvider.future);

      final google = calls.singleWhere((x) => x.name == 'google.nearby');
      expect(google.args['q'], 'ซ่อมท่อ');
      expect(google.args['type'], isNull);
    });

    test('whitespace is not a search', () async {
      final calls = <_Call>[];
      final c = _container(calls: calls);
      c.read(contractorFilterProvider.notifier).setQuery('   ');

      await c.read(contractorsListProvider.future);

      expect(_names(calls), ['saved.search']);
    });

    test('a server with Google off is never asked', () async {
      final calls = <_Call>[];
      final c = _container(
        calls: calls,
        places: _Places(
          calls,
          server: const PlacesServerStatus(enabled: false),
        ),
      );
      c.read(contractorFilterProvider.notifier).setType('plumber');

      await c.read(contractorsListProvider.future);

      expect(_names(calls), ['saved.search'], reason: 'no wasted round trip');
    });

    test('the ★ view uses the household\'s picks and never searches', () async {
      final calls = <_Call>[];
      final c = _container(calls: calls);
      c.read(contractorFilterProvider.notifier).setType('plumber');
      c.read(contractorFilterProvider.notifier).setStarredOnly(true);

      await c.read(contractorsListProvider.future);

      expect(
        _names(calls),
        unorderedEquals(['saved.favorites', 'google.starred']),
      );
      expect(
        c.read(contractorFilterProvider).type,
        isNull,
        reason: '★ replaces the trade filter',
      );
    });

    test('widening the radius re-queries with the new radius', () async {
      final calls = <_Call>[];
      final c = _container(calls: calls);
      c.read(contractorFilterProvider.notifier).setType('plumber');
      await c.read(contractorsListProvider.future);
      calls.clear();

      c.read(contractorFilterProvider.notifier).setRadius(nextRadius(3000)!);
      await c.read(contractorsListProvider.future);

      final google = calls.singleWhere((x) => x.name == 'google.nearby');
      expect(google.args['radius'], 5000);
    });
  });

  group('search centre', () {
    test('a chosen map point replaces the user\'s position', () async {
      final calls = <_Call>[];
      final c = _container(calls: calls);
      c.read(searchCenterProvider.notifier).set(const LatLng(13.80, 100.60));

      await c.read(contractorsListProvider.future);

      final saved = calls.singleWhere((x) => x.name == 'saved.search');
      expect(saved.args['lat'], 13.80);
      expect(saved.args['lng'], 100.60);
    });

    test('works before the first GPS fix when a point was chosen', () async {
      final calls = <_Call>[];
      final c = _container(
        calls: calls,
        loc: const LocationState(resolving: true),
      );
      c.read(searchCenterProvider.notifier).set(const LatLng(13.80, 100.60));

      final r = await c.read(contractorsListProvider.future);

      expect(_names(calls), ['saved.search']);
      expect(r.items, isEmpty);
    });

    test('without a position or a chosen point nothing is queried', () async {
      final calls = <_Call>[];
      final c = _container(
        calls: calls,
        loc: const LocationState(resolving: true),
      );

      final r = await c.read(contractorsListProvider.future);

      expect(calls, isEmpty);
      expect(r.items, isEmpty);
    });

    test('reset goes back to searching around the user', () async {
      final calls = <_Call>[];
      final c = _container(calls: calls);
      final n = c.read(searchCenterProvider.notifier);
      n.set(const LatLng(13.80, 100.60));
      n.reset();

      await c.read(contractorsListProvider.future);

      final saved = calls.singleWhere((x) => x.name == 'saved.search');
      expect(saved.args['lat'], 13.7455);
    });
  });

  group('results', () {
    test(
      'the Google status is passed through for the screen to explain',
      () async {
        final calls = <_Call>[];
        final c = _container(
          calls: calls,
          places: _Places(
            calls,
            result: const GoogleNearby([], GoogleStatus.limited),
          ),
        );
        c.read(contractorFilterProvider.notifier).setType('plumber');

        final r = await c.read(contractorsListProvider.future);

        expect(r.google, GoogleStatus.limited);
      },
    );

    test('a Google twin of a saved contractor is dropped', () async {
      final calls = <_Call>[];
      final saved = Contractor(
        id: 's',
        name: 'ช่างอ้น',
        types: const ['electrician'],
        lat: 13.75,
        lng: 100.53,
      );
      final twin = Contractor(
        id: 'google:g',
        name: 'ช่างอ้น',
        types: const ['electrician'],
        lat: 13.7501,
        lng: 100.5301,
        source: ContractorSource.google,
        placeId: 'g',
      );
      final c = _container(
        calls: calls,
        saved: _Saved(calls, items: [saved]),
        places: _Places(calls, result: GoogleNearby([twin], GoogleStatus.ok)),
      );
      c.read(contractorFilterProvider.notifier).setType('electrician');

      final r = await c.read(contractorsListProvider.future);

      expect(r.items.map((x) => x.id), ['s']);
    });
  });

  group('radius steps', () {
    test('step through the sizes, then stop', () {
      expect(nextRadius(3000), 5000);
      expect(nextRadius(5000), 10000);
      expect(nextRadius(10000), 20000);
      expect(nextRadius(20000), isNull);
    });

    test('an in-between radius goes to the next step up', () {
      expect(nextRadius(4000), 5000);
      expect(nextRadius(1000), 3000);
    });

    test('the first step is the default radius', () {
      expect(const ContractorFilter().radius, kRadiusSteps.first);
    });
  });

  group('filter', () {
    test('picking a trade leaves the ★ view', () {
      final c = _container(calls: []);
      final n = c.read(contractorFilterProvider.notifier);
      n.setStarredOnly(true);
      n.setType('hvac');

      final f = c.read(contractorFilterProvider);
      expect(f.starredOnly, isFalse);
      expect(f.type, 'hvac');
    });

    test('setType(null) really clears the type', () {
      final c = _container(calls: []);
      final n = c.read(contractorFilterProvider.notifier);
      n.setType('plumber');
      n.setType(null);
      expect(c.read(contractorFilterProvider).type, isNull);
    });

    test('changing one field keeps the others', () {
      final c = _container(calls: []);
      final n = c.read(contractorFilterProvider.notifier);
      n.setType('hvac');
      n.setQuery('cool');
      n.setRadius(9000);

      final f = c.read(contractorFilterProvider);
      expect((f.type, f.q, f.radius), ('hvac', 'cool', 9000));
    });
  });

  group('stars', () {
    Contractor google({bool starred = false}) => Contractor(
      id: 'google:g1',
      name: 'ร้าน',
      types: const ['plumber'],
      lat: 13.75,
      lng: 100.53,
      source: ContractorSource.google,
      placeId: 'g1',
      starred: starred,
    );

    test(
      'a saved contractor is flipped through its favorite endpoint',
      () async {
        final calls = <_Call>[];
        final c = _container(calls: calls, saved: _ToggleSaved(calls));
        final saved = Contractor(id: 's1', name: 'ช่าง', types: const []);

        final on = await c.read(starsProvider.notifier).toggle(saved);

        expect(on, isTrue);
        expect(c.read(starsProvider)['s1'], isTrue);
        expect(_names(calls), ['saved.toggle']);
      },
    );

    test('a Google place stores only its id and trade label', () async {
      final calls = <_Call>[];
      final places = _StarPlaces(calls);
      final c = _container(calls: calls, places: places);

      await c.read(starsProvider.notifier).toggle(google());

      expect(places.lastStar, ('g1', true, 'plumber'));
      expect(c.read(starsProvider)['google:g1'], isTrue);
    });

    test('un-starring an already starred place sends off', () async {
      final calls = <_Call>[];
      final places = _StarPlaces(calls);
      final c = _container(calls: calls, places: places);

      final on = await c
          .read(starsProvider.notifier)
          .toggle(google(starred: true));

      expect(on, isFalse);
      expect(places.lastStar, ('g1', false, 'plumber'));
    });

    test('a failure restores the previous state and is rethrown', () async {
      final calls = <_Call>[];
      final c = _container(
        calls: calls,
        places: _StarPlaces(calls, fail: true),
      );

      await expectLater(
        c.read(starsProvider.notifier).toggle(google()),
        throwsA(isA<DioException>()),
      );
      expect(c.read(starsProvider)['google:g1'], isFalse);
    });
  });
}

class _ToggleSaved extends _Saved {
  _ToggleSaved(super.calls);

  @override
  Future<bool> toggleFavorite(String id) async {
    calls.add(_Call('saved.toggle', {'id': id}));
    return true;
  }
}

class _StarPlaces extends _Places {
  _StarPlaces(super.calls, {this.fail = false});
  final bool fail;
  (String, bool, String?)? lastStar;

  @override
  Future<void> setStar(
    String placeId, {
    required bool on,
    String? trade,
  }) async {
    if (fail) throw DioException(requestOptions: RequestOptions());
    lastStar = (placeId, on, trade);
  }
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:homehq/models/contractor.dart';
import 'package:homehq/repositories/contractors_repository.dart';
import 'package:homehq/repositories/places_repository.dart';
import 'package:homehq/screens/contractors_screen.dart';
import 'package:homehq/state/contractors_provider.dart';
import 'package:homehq/state/location_controller.dart';
import 'package:homehq/utils/geo.dart';
import 'package:homehq/widgets/contractors/map_markers.dart';

/// Location controller that never touches Geolocator.
class _FakeLocation extends LocationController {
  _FakeLocation(this.initial);
  final LocationState initial;

  @override
  LocationState build() => initial;

  @override
  Future<void> refresh() async {}
}

/// Tiles that don't hit the network (a 1x1 transparent PNG).
class _BlankTiles extends TileProvider {
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

const _siam = LatLng(13.7455, 100.5342);

/// Saved-contractor repository that records star toggles.
class _FakeSaved extends ContractorsRepository {
  _FakeSaved({this.toggleResult = true, this.failToggle = false})
    : super(Dio());

  final bool toggleResult;
  final bool failToggle;
  final List<String> toggled = [];

  @override
  Future<bool> toggleFavorite(String id) async {
    toggled.add(id);
    if (failToggle) throw DioException(requestOptions: RequestOptions());
    return toggleResult;
  }
}

final _near = Contractor(
  id: 'a',
  name: 'ช่างอ้น',
  types: const ['electrician'],
  phone: '0812345678',
  lat: 13.7649,
  lng: 100.5383,
  distanceM: 99999, // stale server value; the UI must not show this
);
final _noCoords = Contractor(id: 'b', name: 'ช่างไม่มีพิกัด', types: const []);

final _googleShop = Contractor(
  id: 'google:ChIJshop00001',
  name: 'ร้านไฟฟ้ากูเกิล',
  types: const ['electrician'],
  address: 'ถนนพระราม 1',
  lat: 13.7500,
  lng: 100.5300,
  source: ContractorSource.google,
  placeId: 'ChIJshop00001',
  mapsUrl: 'https://www.google.com/maps/search/?api=1&query=x',
);

const _located = LocationState(
  location: UserLocation(
    lat: 13.7455,
    lng: 100.5342,
    accuracy: 20,
    source: LocationSource.currentFix,
  ),
);

Future<void> _pump(
  WidgetTester t, {
  required LocationState loc,
  List<Contractor> list = const [],
  GoogleStatus google = GoogleStatus.off,
  Map<String, PlaceDetails?> details = const {},
  PlacesServerStatus? serverStatus,
  _FakeSaved? saved,
  Size size = const Size(800, 1400),
  Widget? screen,
  void Function()? onQuery,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        locationControllerProvider.overrideWith(() => _FakeLocation(loc)),
        contractorsListProvider.overrideWith((ref) async {
          onQuery?.call();
          return ContractorsResult(list, google: google);
        }),
        placeDetailsProvider.overrideWith(
          (ref, placeId) async => details[placeId],
        ),
        googleStatusProvider.overrideWith((ref) async => serverStatus),
        // The refresh button clears this repository's search memory; the real
        // one needs the app's Dio (and its .env), which tests don't load.
        placesRepoProvider.overrideWithValue(PlacesRepository(Dio())),
        if (saved != null) contractorsRepoProvider.overrideWithValue(saved),
      ],
      child: MaterialApp(
        home: screen ?? ContractorsScreen(tileProvider: _BlankTiles()),
      ),
    ),
  );
  // The location dot pulses forever, so pumpAndSettle would never return.
  // Step the clock instead: results load, camera frames, cards animate.
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('results sheet', () {
    testWidgets('lists contractors with live distance, not the stale one', (
      t,
    ) async {
      await _pump(t, loc: _located, list: [_near, _noCoords]);

      expect(find.text('นายช่างใกล้คุณ'), findsOneWidget);
      expect(find.text('พบ 2 ราย'), findsOneWidget);
      expect(find.text('ช่างอ้น'), findsOneWidget);
      expect(find.text('ช่างไม่มีพิกัด'), findsOneWidget);

      final expected = formatDistance(haversineMeters(_siam, _near.position!));
      expect(find.text(expected), findsOneWidget);
      expect(find.textContaining('99'), findsNothing);
    });

    testWidgets('says it is locating instead of "none found"', (t) async {
      await _pump(t, loc: const LocationState(resolving: true));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('ไม่พบนายช่างในรัศมีที่เลือก'), findsNothing);
      expect(find.text('พบ 0 ราย'), findsNothing);
    });

    testWidgets('blocked location shows an actionable banner', (t) async {
      await _pump(
        t,
        loc: const LocationState(issue: LocationIssue.permissionDeniedForever),
      );

      expect(find.textContaining('ถูกบล็อก'), findsOneWidget);
      expect(find.text('เปิดการตั้งค่า'), findsOneWidget);
      expect(
        find.text('ต้องใช้ตำแหน่งของคุณเพื่อหานายช่างใกล้เคียง'),
        findsOneWidget,
      );
    });

    testWidgets('empty result offers a wider radius', (t) async {
      await _pump(t, loc: _located, list: const []);

      expect(find.text('ไม่พบนายช่างในรัศมีที่เลือก'), findsOneWidget);
      // From the 3 km start, the next step is 5 km.
      expect(find.text('ขยายรัศมีเป็น 5 กม.'), findsOneWidget);
    });

    testWidgets('initialQuery from the home search is applied', (t) async {
      await _pump(
        t,
        loc: _located,
        list: [_near],
        screen: ContractorsScreen(
          initialQuery: 'plumber',
          tileProvider: _BlankTiles(),
        ),
      );

      expect(find.widgetWithText(TextField, 'plumber'), findsOneWidget);
    });
  });

  group('Google results', () {
    testWidgets('are listed, but not pinned on the OSM map', (t) async {
      await _pump(
        t,
        loc: _located,
        list: [_near, _googleShop],
        google: GoogleStatus.ok,
      );

      expect(find.text('ร้านไฟฟ้ากูเกิล'), findsOneWidget);
      expect(find.text('พบ 2 ราย'), findsOneWidget);
      // Google's terms: no Places content on a non-Google map. One pin only:
      // the saved contractor.
      expect(find.byType(ContractorPin), findsOneWidget);
      expect(
        find.text('รวมร้านจาก Google (แสดงในรายการเท่านั้น)'),
        findsOneWidget,
      );
    });

    testWidgets('opening one loads its phone and rating', (t) async {
      await _pump(
        t,
        loc: _located,
        list: [_googleShop],
        google: GoogleStatus.ok,
        details: const {
          'ChIJshop00001': PlaceDetails(
            phone: '081 999 8888',
            rating: 4.6,
            ratingCount: 87,
            openNow: true,
            website: 'https://example.test',
          ),
        },
      );
      expect(find.text('โทร'), findsNothing);

      await t.tap(find.text('ร้านไฟฟ้ากูเกิล'));
      // One frame shows the card selected with the call button still waiting
      // (details are in flight); the next frame has them. Step the clock.
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }

      expect(find.text('081 999 8888'), findsOneWidget);
      // The trade/rating/hours line is a Text.rich, so look inside rich text.
      expect(
        find.textContaining('★ 4.6 (87)', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('เปิดอยู่', findRichText: true),
        findsOneWidget,
      );
      // Contact channels Google publishes, as links under the main actions.
      expect(find.text('เว็บไซต์'), findsOneWidget);
      expect(find.text('เปิดใน Google Maps'), findsOneWidget);
    });

    testWidgets('the distance tool is not offered for them on OSM', (t) async {
      await _pump(
        t,
        loc: _located,
        list: [_googleShop],
        google: GoogleStatus.ok,
      );

      await t.tap(find.text('ร้านไฟฟ้ากูเกิล'));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.text('นำทาง'), findsOneWidget); // hands off to a maps app
      expect(find.text('วัดระยะ'), findsNothing); // would draw on our map
    });

    testWidgets('a saved contractor still gets the distance tool', (t) async {
      await _pump(t, loc: _located, list: [_near], google: GoogleStatus.ok);

      await t.tap(find.text('ช่างอ้น'));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.text('วัดระยะ'), findsOneWidget);
    });

    testWidgets('an unreachable Google is explained, saved ones remain', (
      t,
    ) async {
      await _pump(
        t,
        loc: _located,
        list: [_near],
        google: GoogleStatus.unavailable,
      );

      expect(find.textContaining('ดึงข้อมูลจาก Google ไม่ได้'), findsOneWidget);
      expect(find.text('ช่างอ้น'), findsOneWidget);
    });

    testWidgets('Google being switched off is silent', (t) async {
      await _pump(t, loc: _located, list: [_near], google: GoogleStatus.off);

      expect(find.textContaining('Google'), findsNothing);
    });
  });

  group('paging and scope', () {
    List<Contractor> many(int n) => [
      for (var i = 0; i < n; i++)
        Contractor(
          id: 'c$i',
          name: 'ช่าง ${i.toString().padLeft(2, '0')}',
          types: const ['electrician'],
          lat: 13.7455 + 0.001 * (i + 1),
          lng: 100.5342,
        ),
    ];

    testWidgets('shows a first page, then reveals the rest on request', (
      t,
    ) async {
      await _pump(t, loc: _located, list: many(11));

      // The header counts everything fetched; the list shows one page.
      expect(find.text('พบ 11 ราย'), findsOneWidget);
      expect(find.text('ช่าง 00', skipOffstage: false), findsOneWidget);
      expect(find.text('ช่าง 10', skipOffstage: false), findsNothing);
      expect(
        find.text('ดูเพิ่ม (เหลืออีก 3)', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('once everything is shown, the footer offers a wider radius', (
      t,
    ) async {
      await _pump(t, loc: _located, list: many(3));

      // Nothing hidden, and 3 km is not the widest step.
      expect(find.textContaining('ดูเพิ่ม'), findsNothing);
      expect(
        find.text('ขยายรัศมีเป็น 5 กม.', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('the footer button reveals the hidden results', (t) async {
      // Tall enough that a page of cards and the footer fit in the half-height
      // sheet, so the button is genuinely on screen (not merely built).
      await _pump(
        t,
        loc: _located,
        list: many(11),
        size: const Size(800, 2600),
      );

      await t.tap(find.text('ดูเพิ่ม (เหลืออีก 3)'));
      await t.pump(const Duration(milliseconds: 300));

      // Nothing is hidden any more, so the footer moves on to widening.
      expect(find.textContaining('ดูเพิ่ม', skipOffstage: false), findsNothing);
      expect(
        find.text('ขยายรัศมีเป็น 5 กม.', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('พบ 11 ราย'), findsOneWidget);
    });

    testWidgets('browsing "all" tells you how to get Google results', (
      t,
    ) async {
      await _pump(
        t,
        loc: _located,
        list: [_near],
        serverStatus: const PlacesServerStatus(enabled: true),
      );

      expect(
        find.text('แตะประเภทช่างหรือพิมพ์ค้นหา เพื่อหาร้านจาก Google'),
        findsOneWidget,
      );
    });

    testWidgets('warns when the day\'s Google allowance is nearly gone', (
      t,
    ) async {
      await _pump(
        t,
        loc: _located,
        list: [_near],
        serverStatus: const PlacesServerStatus(
          enabled: true,
          dailyUsed: 290,
          dailyLimit: 300,
        ),
      );

      expect(find.text('โควตา Google วันนี้เหลือ 10 ครั้ง'), findsOneWidget);
    });

    testWidgets('says so when the daily allowance is used up', (t) async {
      await _pump(
        t,
        loc: _located,
        list: [_near],
        google: GoogleStatus.limited,
      );

      expect(
        find.textContaining('ใช้โควตา Google ของวันนี้ครบแล้ว'),
        findsOneWidget,
      );
      expect(find.text('ช่างอ้น'), findsOneWidget); // saved ones remain
    });
  });

  group('follow mode', () {
    testWidgets(
      'the location button follows you, and stops when tapped again',
      (t) async {
        await _pump(t, loc: _located, list: [_near]);
        expect(find.byTooltip('ตำแหน่งของฉัน'), findsOneWidget);
        expect(find.byTooltip('หยุดตามตำแหน่ง'), findsNothing);

        await t.tap(find.byTooltip('ตำแหน่งของฉัน'));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byTooltip('หยุดตามตำแหน่ง'), findsOneWidget);

        await t.tap(find.byTooltip('หยุดตามตำแหน่ง'));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byTooltip('ตำแหน่งของฉัน'), findsOneWidget);
      },
    );

    testWidgets('picking a contractor stops following', (t) async {
      await _pump(t, loc: _located, list: [_near]);

      await t.tap(find.byTooltip('ตำแหน่งของฉัน'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('หยุดตามตำแหน่ง'), findsOneWidget);

      await t.tap(find.text('ช่างอ้น'));
      await t.pump(const Duration(milliseconds: 400));
      // The camera went to the contractor; following would drag it back.
      expect(find.byTooltip('ตำแหน่งของฉัน'), findsOneWidget);
    });
  });

  group('stars', () {
    testWidgets('a starred contractor is listed ahead of a nearer one', (
      t,
    ) async {
      final nearer = Contractor(
        id: 'n',
        name: 'ใกล้กว่า',
        types: const ['plumber'],
        lat: 13.7460,
        lng: 100.5342,
      );
      final farStarred = Contractor(
        id: 'f',
        name: 'ไกลแต่ไว้ใจ',
        types: const ['plumber'],
        lat: 13.7600,
        lng: 100.5342,
        starred: true,
      );
      await _pump(t, loc: _located, list: [nearer, farStarred]);

      final near = t.getTopLeft(find.text('ใกล้กว่า')).dy;
      final star = t.getTopLeft(find.text('ไกลแต่ไว้ใจ')).dy;
      expect(star, lessThan(near), reason: 'starred must come first');
    });

    testWidgets('tapping the star flips it without reloading the list', (
      t,
    ) async {
      final saved = _FakeSaved(toggleResult: true);
      await _pump(t, loc: _located, list: [_near], saved: saved);
      expect(find.byTooltip('ติดดาวช่างประจำ'), findsOneWidget);

      await t.tap(find.byTooltip('ติดดาวช่างประจำ'));
      await t.pump(const Duration(milliseconds: 200));

      expect(saved.toggled, ['a']);
      expect(find.byTooltip('เอาดาวออก'), findsOneWidget);
    });

    testWidgets('a failed star is undone and reported', (t) async {
      final saved = _FakeSaved(failToggle: true);
      await _pump(t, loc: _located, list: [_near], saved: saved);

      await t.tap(find.byTooltip('ติดดาวช่างประจำ'));
      await t.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('ติดดาวช่างประจำ'), findsOneWidget); // back to off
    });

    testWidgets('the ★ chip switches to the household\'s picks', (t) async {
      await _pump(t, loc: _located, list: [_near]);
      final container = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      );

      await t.tap(find.text('ช่างประจำ'));
      await t.pump(const Duration(milliseconds: 100));
      expect(container.read(contractorFilterProvider).starredOnly, isTrue);

      await t.tap(find.text('ช่างประจำ'));
      await t.pump(const Duration(milliseconds: 100));
      expect(container.read(contractorFilterProvider).starredOnly, isFalse);
    });
  });

  group('map', () {
    testWidgets('pins only contractors that have coordinates', (t) async {
      await _pump(t, loc: _located, list: [_near, _noCoords]);

      expect(find.byType(ContractorPin), findsOneWidget);
    });

    testWidgets('marks where you are', (t) async {
      await _pump(t, loc: _located, list: [_near]);

      expect(find.byType(MyLocationDot), findsOneWidget);
      expect(find.text('คุณอยู่ที่นี่'), findsOneWidget);
    });

    testWidgets('a hand-placed pin is labelled as such', (t) async {
      await _pump(
        t,
        loc: const LocationState(
          location: UserLocation(
            lat: 13.7455,
            lng: 100.5342,
            source: LocationSource.manual,
          ),
        ),
        list: [_near],
      );

      expect(find.text('ตำแหน่งที่ปักไว้'), findsOneWidget);
      expect(find.text('คุณอยู่ที่นี่'), findsNothing);
    });

    testWidgets('credits the map data', (t) async {
      await _pump(t, loc: _located, list: [_near]);

      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    });
  });

  group('selection', () {
    testWidgets('the refresh button asks for the results again', (t) async {
      var queries = 0;
      await _pump(t, loc: _located, list: [_near], onQuery: () => queries++);
      expect(queries, 1);

      await t.tap(find.byTooltip('รีเฟรช'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      // The old list is replaced by a loader while it re-queries.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      // ...but the button itself shows none: only the loader in the sheet.
      expect(
        find.descendant(
          of: find.byTooltip('รีเฟรช'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(find.text('ช่างอ้น'), findsNothing);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      expect(queries, 2);
    });

    testWidgets('tapping a card opens its actions', (t) async {
      await _pump(t, loc: _located, list: [_near]);
      expect(find.text('นำทาง'), findsNothing);

      await t.tap(find.text('ช่างอ้น'));
      await t.pump(const Duration(milliseconds: 400));

      // The call button carries the number: it is the contact channel.
      expect(find.text('0812345678'), findsOneWidget);
      expect(find.text('นำทาง'), findsOneWidget);
      expect(find.text('วัดระยะ'), findsOneWidget);
    });

    testWidgets('tapping a pin selects the same contractor', (t) async {
      await _pump(t, loc: _located, list: [_near]);
      expect(find.text('นำทาง'), findsNothing);

      await t.tap(find.byType(ContractorPin));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.text('นำทาง'), findsOneWidget);
    });

    testWidgets('?focus= selects that contractor once results arrive', (
      t,
    ) async {
      await _pump(
        t,
        loc: _located,
        list: [_near],
        screen: ContractorsScreen(focusId: 'a', tileProvider: _BlankTiles()),
      );

      expect(find.text('นำทาง'), findsOneWidget);
    });
  });

  group('filters', () {
    testWidgets('trade chips set and clear the type filter', (t) async {
      await _pump(t, loc: _located, list: [_near]);
      final container = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      );

      await t.tap(find.text('ช่างประปา'));
      await t.pump(const Duration(milliseconds: 100));
      expect(container.read(contractorFilterProvider).type, 'plumber');

      await t.tap(find.text('ช่างประปา'));
      await t.pump(const Duration(milliseconds: 100));
      expect(container.read(contractorFilterProvider).type, isNull);
    });

    testWidgets('the radius pill opens the picker', (t) async {
      await _pump(t, loc: _located, list: [_near]);

      await t.tap(find.text('3 กม.'));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.text('รัศมีค้นหา'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  group('measure tool', () {
    testWidgets('start from me, tap a pin, read the distance', (t) async {
      await _pump(t, loc: _located, list: [_near]);

      await t.tap(find.byTooltip('วัดระยะ'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('0 ม.'), findsOneWidget);
      // The results sheet gives way to the measure panel.
      expect(find.text('นายช่างใกล้คุณ'), findsNothing);

      await t.tap(find.text('เริ่มจากตำแหน่งฉัน'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('(1 จุด)'), findsOneWidget);

      // While measuring, a pin adds its exact position as a point.
      await t.tap(find.byType(ContractorPin));
      await t.pump(const Duration(milliseconds: 200));

      final expected = formatDistance(haversineMeters(_siam, _near.position!));
      expect(find.text('(2 จุด)'), findsOneWidget);
      expect(find.text(expected), findsOneWidget);

      await t.tap(find.text('ล้าง'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('(0 จุด)'), findsOneWidget);
    });
  });

  group('ContractorFilterNotifier', () {
    test('setType(null) really clears the type', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(contractorFilterProvider.notifier);

      n.setType('plumber');
      expect(c.read(contractorFilterProvider).type, 'plumber');
      n.setType(null);
      expect(c.read(contractorFilterProvider).type, isNull);
    });

    test('changing one field keeps the others', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(contractorFilterProvider.notifier);

      n.setType('hvac');
      n.setQuery('cool');
      n.setRadius(9000);
      final f = c.read(contractorFilterProvider);
      expect((f.type, f.q, f.radius), ('hvac', 'cool', 9000));
    });
  });
}

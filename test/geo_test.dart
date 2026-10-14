import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:homeservice/models/contractor.dart';
import 'package:homeservice/utils/geo.dart';

void main() {
  // Siam Square → Victory Monument, central Bangkok. ~2.4 km as the crow flies.
  const siam = LatLng(13.7455, 100.5342);
  const victory = LatLng(13.7649, 100.5383);

  group('haversineMeters', () {
    test('identical points are 0 m (and never NaN)', () {
      expect(haversineMeters(siam, siam), 0);
    });

    test('one degree of latitude is ~111.2 km', () {
      final d = haversineMeters(const LatLng(0, 0), const LatLng(1, 0));
      expect(d, closeTo(111195, 50));
    });

    test('known city pair is about 2.2 km', () {
      final d = haversineMeters(siam, victory);
      expect(d, inInclusiveRange(2100, 2300));
    });

    test('is symmetric', () {
      expect(
        haversineMeters(siam, victory),
        closeTo(haversineMeters(victory, siam), 1e-6),
      );
    });

    test('antipodal points do not blow up asin()', () {
      final d = haversineMeters(const LatLng(0, 0), const LatLng(0, 180));
      expect(d.isNaN, isFalse);
      expect(d, closeTo(20015087, 1000)); // half the circumference
    });
  });

  group('pathLengthMeters', () {
    test('empty and single-point paths are 0', () {
      expect(pathLengthMeters(const []), 0);
      expect(pathLengthMeters(const [siam]), 0);
    });

    test('sums the legs in order', () {
      const mid = LatLng(13.7550, 100.5360);
      final expected =
          haversineMeters(siam, mid) + haversineMeters(mid, victory);
      expect(
        pathLengthMeters(const [siam, mid, victory]),
        closeTo(expected, 1e-6),
      );
      // A detour can never be shorter than the straight line.
      expect(
        pathLengthMeters(const [siam, mid, victory]),
        greaterThanOrEqualTo(haversineMeters(siam, victory) - 1e-6),
      );
    });
  });

  group('formatDistance', () {
    test('metres below 1 km', () {
      expect(formatDistance(0), '0 ม.');
      expect(formatDistance(849.6), '850 ม.');
    });

    test('does not show "1000 ม."', () {
      expect(formatDistance(999.6), '1.0 กม.');
    });

    test('one decimal under 10 km, whole km above', () {
      expect(formatDistance(3420), '3.4 กม.');
      expect(formatDistance(12400), '12 กม.');
    });
  });

  group('Contractor', () {
    Map<String, dynamic> json({Object? lat, Object? lng, Object? d}) => {
      'id': 'c1',
      'name': 'ช่างอ้น',
      'types': ['electrician'],
      'lat': lat,
      'lng': lng,
      'distance_m': d,
    };

    test('parses a contractor that has no coordinates', () {
      final c = Contractor.fromJson(json());
      expect(c.position, isNull);
      expect(c.distanceFrom(siam), isNull);
    });

    test('tolerates missing types', () {
      final c = Contractor.fromJson({'id': 'c1', 'name': 'x'});
      expect(c.types, isEmpty);
    });

    test('distanceFrom uses live origin, falls back to server value', () {
      final c = Contractor.fromJson(json(lat: 13.7649, lng: 100.5383, d: 9999));
      expect(c.distanceFrom(null), 9999);
      expect(
        c.distanceFrom(siam),
        closeTo(haversineMeters(siam, victory), 1e-6),
      );
    });
  });
}

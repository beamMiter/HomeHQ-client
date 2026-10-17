import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import '../l10n/app_localizations.dart';

/// Same earth radius the server uses in its SQL distance expression, so a
/// distance shown on the client matches what the API filters on.
const double earthRadiusMeters = 6371000;

double _rad(double deg) => deg * math.pi / 180;

/// Great-circle distance in metres between [a] and [b] (haversine).
double haversineMeters(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  // min() guards asin() against h drifting a hair above 1.
  return 2 * earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Total length in metres of the path through [points], in order.
double pathLengthMeters(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += haversineMeters(points[i - 1], points[i]);
  }
  return total;
}

/// "850 ม." below 1 km, otherwise "3.4 กม." (whole km from 10 km up).
///
/// Pass [l10n] to get the unit in the app's language; without it the Thai
/// units are used (what the plain-Dart tests assert).
String formatDistance(double meters, [AppLocalizations? l10n]) {
  final m = meters.round();
  if (m < 1000) return l10n == null ? '$m ม.' : l10n.distMeters('$m');
  final km = meters / 1000;
  final v = km.toStringAsFixed(km < 10 ? 1 : 0);
  return l10n == null ? '$v กม.' : l10n.distKm(v);
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/weather.dart';
import '../services/weather_service.dart';
import 'location_controller.dart';

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(),
);

final currentWeatherProvider = FutureProvider<WeatherNow>((ref) async {
  // Coarse cell: weather isn't refetched on every GPS tick.
  final (pos, issue) = ref.watch(
    locationControllerProvider.select((s) => (coarseCell(s.location), s.issue)),
  );

  if (pos == null) {
    if (issue != null) throw LocationUnavailableException(issue);
    // Still locating: stay in "loading". This provider rebuilds as soon as the
    // location controller reports a fix or an issue.
    return Completer<WeatherNow>().future;
  }

  return ref.read(weatherServiceProvider).getCurrent(pos.lat, pos.lng);
});

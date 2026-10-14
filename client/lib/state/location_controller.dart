import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/l10n.dart';

enum LocationSource { lastKnown, currentFix, stream, manual }

/// Why there is no (fresh) location. Tells the UI which action to offer.
enum LocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class UserLocation {
  final double lat;
  final double lng;
  final double? accuracy; // metres
  final LocationSource source;
  const UserLocation({
    required this.lat,
    required this.lng,
    this.accuracy,
    required this.source,
  });

  LatLng get latLng => LatLng(lat, lng);
}

/// [l] snapped to a ~1 km grid (0.01°), or null when there is no position.
///
/// Providers that fetch data per location should `select` this instead of the
/// raw position, so they refetch when the user has actually moved somewhere new
/// (or pinned a spot by hand) rather than on every GPS tick.
({double lat, double lng})? coarseCell(UserLocation? l) {
  if (l == null) return null;
  double snap(double v) => (v * 100).roundToDouble() / 100;
  return (lat: snap(l.lat), lng: snap(l.lng));
}

class LocationState {
  /// Best known position. Kept while an [issue] is raised so screens can keep
  /// showing the last fix instead of going blank.
  final UserLocation? location;
  final LocationIssue? issue;
  final bool resolving;
  const LocationState({this.location, this.issue, this.resolving = false});
}

/// Thrown by providers that can't proceed without a location.
class LocationUnavailableException implements Exception, LocalizedError {
  const LocationUnavailableException(this.issue);
  final LocationIssue issue;

  @override
  String localized(AppLocalizations l10n) => switch (issue) {
    LocationIssue.serviceDisabled => l10n.locErrServiceOff,
    LocationIssue.permissionDenied => l10n.locErrDenied,
    LocationIssue.permissionDeniedForever => l10n.locErrBlocked,
    LocationIssue.unavailable => l10n.locErrUnknown,
  };

  // Log text (not shown to the user): English, for developers.
  @override
  String toString() => switch (issue) {
    LocationIssue.serviceDisabled => 'Location services are turned off.',
    LocationIssue.permissionDenied => 'Location permission was denied.',
    LocationIssue.permissionDeniedForever =>
      'Location permission is blocked. Enable it in Settings.',
    LocationIssue.unavailable => 'Could not determine your location.',
  };
}

/// The single source of truth for the device position. Everything that needs
/// GPS (weather, contractors, map) should read this rather than calling
/// Geolocator itself, so permission prompts and fixes happen once.
class LocationController extends Notifier<LocationState> {
  StreamSubscription<Position>? _sub;

  @override
  LocationState build() {
    ref.onDispose(() => _sub?.cancel());
    // State can't be changed while building; start right after.
    Future.microtask(refresh);
    return const LocationState(resolving: true);
  }

  /// (Re)check service + permission and get a fresh fix. Also what the UI's
  /// retry button should call, e.g. after the user returns from Settings.
  Future<void> refresh() async {
    state = LocationState(location: state.location, resolving: true);

    final issue = await _checkAccess();
    if (issue != null) {
      await _stopStream();
      state = LocationState(location: state.location, issue: issue);
      return;
    }

    // 1) Last known: instant but possibly stale. Not supported on every
    //    platform (e.g. web), hence the guard.
    if (state.location == null) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _emit(last, LocationSource.lastKnown);
      } catch (e) {
        if (kDebugMode) debugPrint('[loc:lastKnown] $e');
      }
    }

    // 2) A real fix. timeLimit stops us hanging when the device has no signal
    //    (e.g. an iOS Simulator whose location is set to "None").
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _emit(pos, LocationSource.currentFix);
    } catch (e) {
      if (kDebugMode) debugPrint('[loc:currentFix] $e');
      state = LocationState(
        location: state.location,
        issue: state.location == null ? LocationIssue.unavailable : null,
      );
    }

    // 3) Keep following. 30 m is fine enough for a "you are here" dot without
    //    waking the GPS constantly.
    await _stopStream();
    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 30,
          ),
        ).listen(
          (pos) => _emit(pos, LocationSource.stream),
          onError: (Object e, StackTrace _) {
            if (kDebugMode) debugPrint('[loc:stream] $e');
            if (e is LocationServiceDisabledException) {
              state = LocationState(
                location: state.location,
                issue: LocationIssue.serviceDisabled,
              );
            }
          },
        );
  }

  /// Pin the position by hand (e.g. a long-press on the map). Stops GPS
  /// tracking until [refresh] is called.
  void setManual(double lat, double lng) {
    _stopStream();
    state = LocationState(
      location: UserLocation(lat: lat, lng: lng, source: LocationSource.manual),
    );
  }

  void _emit(Position pos, LocationSource source) {
    state = LocationState(
      location: UserLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        source: source,
      ),
    );
  }

  Future<void> _stopStream() async {
    final s = _sub;
    _sub = null;
    await s?.cancel();
  }

  Future<LocationIssue?> _checkAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationIssue.serviceDisabled;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return switch (perm) {
      LocationPermission.deniedForever => LocationIssue.permissionDeniedForever,
      LocationPermission.denied => LocationIssue.permissionDenied,
      _ => null,
    };
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

import 'package:latlong2/latlong.dart';

import '../utils/geo.dart';

/// Where a contractor came from.
enum ContractorSource {
  /// One the household saved in the app's own database.
  saved,

  /// A business found through Google Places. Never stored on our side.
  google,
}

class Contractor {
  final String id;
  final String name;
  final List<String> types;
  final String? phone;
  final String? address;

  /// Null for contractors saved without a location; they can't be placed on a
  /// map or matched by a radius search.
  final double? lat, lng;

  /// Distance in metres computed by the server for the position it was queried
  /// with. Prefer [distanceFrom] for anything shown live.
  final double? distanceM;

  final ContractorSource source;

  /// Google's id for this place (google results only).
  final String? placeId;

  /// Link that opens this place in Google Maps (google results only).
  final String? mapsUrl;

  /// Whether the household starred this one. For a saved contractor this is
  /// the `is_favorite` flag; for a Google place it is a bookmark that stores
  /// nothing but the place id.
  final bool starred;

  /// Quality and contact info. Not part of a search result: filled in from
  /// [PlaceDetails] once the user opens a Google result.
  final double? rating;
  final int? ratingCount;
  final bool? openNow;
  final String? website;

  Contractor({
    required this.id,
    required this.name,
    required this.types,
    this.phone,
    this.address,
    this.lat,
    this.lng,
    this.distanceM,
    this.source = ContractorSource.saved,
    this.placeId,
    this.mapsUrl,
    this.starred = false,
    this.rating,
    this.ratingCount,
    this.openNow,
    this.website,
  });

  factory Contractor.fromJson(Map<String, dynamic> j) {
    final isGoogle = j['source'] == 'google';
    return Contractor(
      id: j['id'].toString(),
      name: (j['name'] ?? '').toString(),
      types: (j['types'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      phone: j['phone'] as String?,
      address: j['address'] as String?,
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      distanceM: (j['distance_m'] as num?)?.toDouble(),
      source: isGoogle ? ContractorSource.google : ContractorSource.saved,
      placeId: isGoogle ? j['place_id'] as String? : null,
      mapsUrl: isGoogle
          ? j['maps_url'] as String?
          : j['google_maps_url'] as String?,
      starred: (isGoogle ? j['starred'] : j['is_favorite']) == true,
    );
  }

  bool get isGoogle => source == ContractorSource.google;

  LatLng? get position =>
      (lat == null || lng == null) ? null : LatLng(lat!, lng!);

  /// Distance in metres from [origin] (typically the user's live GPS fix).
  /// Falls back to the server-computed value while [origin] is unknown, and is
  /// null when this contractor has no coordinates.
  double? distanceFrom(LatLng? origin) {
    final p = position;
    if (p == null) return null;
    if (origin == null) return distanceM;
    return haversineMeters(origin, p);
  }

  /// This contractor with Google's on-demand fields applied. Search results
  /// are left as they are; the merged copy is only used for display.
  Contractor withDetails(PlaceDetails d) => Contractor(
    id: id,
    name: name,
    types: types,
    phone: d.phone ?? phone,
    address: address,
    lat: lat,
    lng: lng,
    distanceM: distanceM,
    source: source,
    placeId: placeId,
    mapsUrl: d.mapsUrl ?? mapsUrl,
    starred: starred,
    rating: d.rating ?? rating,
    ratingCount: d.ratingCount ?? ratingCount,
    openNow: d.openNow ?? openNow,
    website: d.website ?? website,
  );

  /// The same contractor with its star flag set.
  Contractor withStarred(bool value) => Contractor(
    id: id,
    name: name,
    types: types,
    phone: phone,
    address: address,
    lat: lat,
    lng: lng,
    distanceM: distanceM,
    source: source,
    placeId: placeId,
    mapsUrl: mapsUrl,
    starred: value,
    rating: rating,
    ratingCount: ratingCount,
    openNow: openNow,
    website: website,
  );
}

/// What Google tells us about one place on demand (phone, rating, hours).
class PlaceDetails {
  const PlaceDetails({
    this.phone,
    this.rating,
    this.ratingCount,
    this.openNow,
    this.website,
    this.mapsUrl,
  });

  final String? phone;
  final double? rating;
  final int? ratingCount;
  final bool? openNow;
  final String? website;
  final String? mapsUrl;

  factory PlaceDetails.fromJson(Map<String, dynamic> j) {
    String? nonEmpty(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return PlaceDetails(
      phone: nonEmpty(j['phone']) ?? nonEmpty(j['international_phone']),
      rating: (j['rating'] as num?)?.toDouble(),
      ratingCount: (j['rating_count'] as num?)?.toInt(),
      openNow: j['open_now'] as bool?,
      website: nonEmpty(j['website']),
      mapsUrl: nonEmpty(j['maps_url']),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/contractor.dart';
import '../repositories/contractors_repository.dart';
import '../repositories/places_repository.dart';
import '../services/api_client.dart' show apiClientProvider;
import '../utils/geo.dart';
import 'location_controller.dart';

// Uses the shared ApiClient Dio: /contractors is behind RequireAuth, so it
// needs the auth interceptor and the configured base URL.
final contractorsRepoProvider = Provider<ContractorsRepository>(
  (ref) => ContractorsRepository(ref.watch(apiClientProvider).dio),
);

final placesRepoProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(ref.watch(apiClientProvider).dio),
);

// ── Search scope ────────────────────────────────────────────────────────────
//
// Sized for one household. Everything here is a constant on purpose so the
// numbers can be reviewed (and changed) in one place.

/// Search radii the "see more" button steps through, in metres. The first is
/// the starting radius: 3 km covers a Bangkok neighbourhood.
const kRadiusSteps = <int>[3000, 5000, 10000, 20000];

/// Results shown before the user asks for more.
const kPageSize = 8;

/// The next radius after [current], or null when already at the widest.
int? nextRadius(int current) {
  for (final r in kRadiusSteps) {
    if (r > current) return r;
  }
  return null;
}

/// ---- Filter model ----
class ContractorFilter {
  final String? type; // electrician|plumber|carpenter|hvac
  final String q;
  final int radius; // meters

  /// Show only starred contractors/places, wherever they are.
  final bool starredOnly;

  const ContractorFilter({
    this.type,
    this.q = '',
    this.radius = 3000,
    this.starredOnly = false,
  });

  /// Whether this filter is asking Google for businesses. Browsing "all" shows
  /// what the household already knows and costs no Google call; Google is for
  /// when a trade is picked or something is typed.
  bool get wantsGoogle => !starredOnly && (type != null || q.trim().isNotEmpty);
}

/// ---- Notifier API (Riverpod v3) ----
class ContractorFilterNotifier extends Notifier<ContractorFilter> {
  @override
  ContractorFilter build() => const ContractorFilter();

  ContractorFilter _with({
    Object? type = _keep,
    String? q,
    int? radius,
    bool? starredOnly,
  }) => ContractorFilter(
    type: identical(type, _keep) ? state.type : type as String?,
    q: q ?? state.q,
    radius: radius ?? state.radius,
    starredOnly: starredOnly ?? state.starredOnly,
  );

  static const _keep = Object();

  void setQuery(String q) => state = _with(q: q);

  // `type: null` really clears the type (a plain `??` could not tell "clear"
  // from "leave alone").
  void setType(String? type) => state = _with(type: type, starredOnly: false);

  void setRadius(int radius) => state = _with(radius: radius);

  // The ★ view is its own thing: it replaces the trade filter rather than
  // combining with it, so the chips never disagree with what is shown.
  void setStarredOnly(bool on) =>
      state = _with(type: on ? null : state.type, starredOnly: on);
}

final contractorFilterProvider =
    NotifierProvider<ContractorFilterNotifier, ContractorFilter>(
      ContractorFilterNotifier.new,
    );

/// A point on the map the user chose to search around ("ค้นหาในพื้นที่นี้"),
/// or null to search around themselves.
class SearchCenterNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void set(LatLng p) => state = p;
  void reset() => state = null;
}

final searchCenterProvider = NotifierProvider<SearchCenterNotifier, LatLng?>(
  SearchCenterNotifier.new,
);

/// Whether the server has Google configured, and how much of today's allowance
/// is left. Costs no Google call. Null when the server can't be asked.
final googleStatusProvider = FutureProvider<PlacesServerStatus?>(
  (ref) => ref.watch(placesRepoProvider).status(),
);

// ── Results ─────────────────────────────────────────────────────────────────

/// What a search found: the household's saved contractors plus, when the
/// server has Google configured and the user asked for it, businesses from
/// Google Places.
class ContractorsResult {
  const ContractorsResult(this.items, {this.google = GoogleStatus.off});

  /// Saved and Google results together (unsorted; the screen orders them).
  final List<Contractor> items;
  final GoogleStatus google;

  bool get hasGoogleItems => items.any((c) => c.isGoogle);
}

/// Merges saved contractors with Google results.
///
/// A shop the household already saved usually also exists on Google. Showing
/// both is noise, and the saved one is the one with the family's own note and
/// number, so a Google result that matches a saved contractor is dropped.
///
/// "Matches" = within [sameShopMeters] and one name contains the other (after
/// ignoring case, spaces and punctuation).
List<Contractor> mergeSavedAndGoogle(
  List<Contractor> saved,
  List<Contractor> google, {
  double sameShopMeters = 120,
}) {
  String norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\.\-_,()/]+'), '');

  bool sameShop(Contractor g) {
    final gp = g.position;
    if (gp == null) return false;
    final gn = norm(g.name);
    for (final s in saved) {
      final sp = s.position;
      if (sp == null) continue;
      if (haversineMeters(sp, gp) > sameShopMeters) continue;
      final sn = norm(s.name);
      if (sn.isEmpty || gn.isEmpty) continue;
      if (sn.contains(gn) || gn.contains(sn)) return true;
    }
    return false;
  }

  return [...saved, ...google.where((g) => !sameShop(g))];
}

/// Contractors for the current filter and search centre.
///
/// What costs what:
///   * saved contractors: our own database, always queried;
///   * starred places: one cheap Google lookup each (capped on the server),
///     only when the ★ filter is on;
///   * Google search: one call, only when a trade is picked or text typed.
///
/// Re-queries when the filter or search centre changes, or when the user has
/// moved to a new ~1 km cell (only while searching around themselves). Not on
/// every GPS tick: distances are recomputed live, so the list needn't reload.
final contractorsListProvider = FutureProvider<ContractorsResult>((ref) async {
  final repo = ref.watch(contractorsRepoProvider);
  final places = ref.watch(placesRepoProvider);
  final filter = ref.watch(contractorFilterProvider);
  final center = ref.watch(searchCenterProvider);

  // Around the map point if one was chosen; otherwise around the user, and
  // then only the coarse cell is watched so GPS jitter doesn't re-query.
  double lat, lng;
  if (center != null) {
    lat = center.latitude;
    lng = center.longitude;
  } else {
    final cell = ref.watch(
      locationControllerProvider.select((s) => coarseCell(s.location)),
    );
    // No position yet: nothing to query. The screen shows a location banner.
    if (cell == null) return const ContractorsResult([]);
    final loc = ref.read(locationControllerProvider).location!;
    lat = loc.lat;
    lng = loc.lng;
  }

  // A newer query makes this one irrelevant; stop waiting on (and, where the
  // server notices, paying for) the old one.
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);

  final q = filter.q.trim().isEmpty ? null : filter.q.trim();

  // Don't ask Google when the server already said it is off.
  PlacesServerStatus? server;
  try {
    server = await ref.watch(googleStatusProvider.future);
  } catch (_) {
    server = null;
  }
  final googleOn = server?.enabled ?? true; // unknown: try, it never throws

  // ★ filter: the household's own picks, no radius.
  if (filter.starredOnly) {
    final googleFuture = googleOn
        ? places.starred(lat: lat, lng: lng, cancelToken: cancel)
        : Future.value(const GoogleNearby.off());
    final saved = await repo.favorites(cancelToken: cancel);
    final google = await googleFuture;
    return ContractorsResult(
      mergeSavedAndGoogle(saved, google.items),
      google: google.status,
    );
  }

  // Both run at once. Google never throws (see PlacesRepository), so starting
  // it first can't leave an unhandled error behind if the saved search fails.
  final googleFuture = (googleOn && filter.wantsGoogle)
      ? places.nearby(
          lat: lat,
          lng: lng,
          radius: filter.radius,
          type: filter.type,
          q: q,
          cancelToken: cancel,
        )
      : Future.value(const GoogleNearby.off());

  final saved = await repo.search(
    lat: lat,
    lng: lng,
    radius: filter.radius,
    type: filter.type,
    q: q,
    cancelToken: cancel,
  );
  final google = await googleFuture;

  return ContractorsResult(
    mergeSavedAndGoogle(saved, google.items),
    // "off" is also what an un-asked Google reports; only a real answer
    // changes what the screen says about it.
    google: google.status,
  );
});

/// Phone, rating, website and opening status for one Google place, fetched only
/// when the user opens that place (it is the pricier request).
final placeDetailsProvider = FutureProvider.autoDispose
    .family<PlaceDetails?, String>(
      (ref, placeId) => ref.watch(placesRepoProvider).details(placeId),
    );

// ── Stars ───────────────────────────────────────────────────────────────────

/// Star state changed this session, keyed by contractor id. Layered over what
/// the last search returned so a tap shows instantly and the list never has to
/// reload (which, for Google results, would cost a call) just to move a star.
class StarsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const {};

  /// The star state to show for [c].
  bool effective(Contractor c) => state[c.id] ?? c.starred;

  /// Flips [c]'s star. Returns the state afterwards; on failure the previous
  /// state is restored and the error rethrown so the screen can say so.
  Future<bool> toggle(Contractor c) async {
    final before = effective(c);
    final want = !before;
    state = {...state, c.id: want};

    try {
      if (c.isGoogle) {
        final placeId = c.placeId;
        if (placeId == null) throw StateError('google result without place id');
        await ref
            .read(placesRepoProvider)
            .setStar(
              placeId,
              on: want,
              trade: c.types.isEmpty ? null : c.types.first,
            );
        return want;
      }
      // Saved contractors: the server flips and tells us where it landed.
      final landed = await ref
          .read(contractorsRepoProvider)
          .toggleFavorite(c.id);
      state = {...state, c.id: landed};
      return landed;
    } catch (_) {
      state = {...state, c.id: before};
      rethrow;
    }
  }
}

final starsProvider = NotifierProvider<StarsNotifier, Map<String, bool>>(
  StarsNotifier.new,
);

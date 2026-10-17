import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contractor.dart';
import '../config/map_config.dart';
import '../models/contractor_type.dart';
import '../repositories/places_repository.dart';
import '../shared/app_colors.dart';
import '../state/contractors_provider.dart';
import '../state/location_controller.dart';
import '../utils/geo.dart';
import '../utils/map_launcher.dart';
import '../widgets/contractors/contractor_card.dart';
import '../widgets/contractors/map_markers.dart';
import '../widgets/contractors/measure_card.dart';
import '../widgets/contractors/radius_sheet.dart';
import '../widgets/error_state.dart';
import '../widgets/list_empty_state.dart';
import '../widgets/location_banner.dart';
import '../widgets/refresh.dart';
import '../widgets/toast.dart';
import '../l10n/l10n.dart';

// OpenStreetMap's own tile server: free and needs no API key, but its usage
// policy is for light use. Before shipping at scale, point this at a provider
// you have an account with (MapTiler, Stadia, Thunderforest, ...).
// CARTO's free raster tiles now require a key, so they are not an option.
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Mutes the stock OSM palette (saturation 55%, slightly lifted) so pins, the
/// radius ring and the UI on top read clearly instead of fighting the map.
const _softTiles = ColorFilter.matrix(<double>[
  0.2126 * 0.45 + 0.55, 0.7152 * 0.45, 0.0722 * 0.45, 0, 10, //
  0.2126 * 0.45, 0.7152 * 0.45 + 0.55, 0.0722 * 0.45, 0, 10, //
  0.2126 * 0.45, 0.7152 * 0.45, 0.0722 * 0.45 + 0.55, 0, 10, //
  0, 0, 0, 1, 0,
]);

/// Contractors near you, on a map.
///
/// The map fills the screen. Search, trade filters and the radius float on top
/// of it, and the results live in a bottom sheet you can drag between a peek,
/// half and full height. Tapping a pin or a card selects the contractor: the
/// map flies to it and the card opens its actions.
class ContractorsScreen extends ConsumerStatefulWidget {
  const ContractorsScreen({
    super.key,
    this.initialQuery,
    this.focusId,
    this.tileProvider,
  });

  /// Pre-filled search, e.g. from the home screen's search box (?q=...).
  final String? initialQuery;

  /// Contractor to select as soon as results arrive (?focus=...).
  final String? focusId;

  /// Test hook. Null uses the default network tile provider.
  final TileProvider? tileProvider;

  @override
  ConsumerState<ContractorsScreen> createState() => _ContractorsScreenState();
}

class _ContractorsScreenState extends ConsumerState<ContractorsScreen>
    with SingleTickerProviderStateMixin {
  // Shown until the first GPS fix arrives (central Bangkok).
  static const _fallbackCenter = LatLng(13.7563, 100.5018);

  // Sheet heights as a fraction of the screen.
  static const _peek = 0.17;
  static const _mid = 0.42;
  static const _tall = 0.9;

  // Fixed geometry, so we can scroll the sheet to a card by index.
  static const _headerExtent = 78.0;
  static const _cardGap = 10.0;

  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  final _sheetSize = ValueNotifier<double>(_mid);

  late final AnimationController _camAc = AnimationController(vsync: this);
  VoidCallback? _camListener;

  ScrollController? _listCtrl;

  /// What is shown, in order (the first page(s) of everything fetched).
  List<Contractor> _ordered = const [];

  final List<LatLng> _path = [];
  bool _mapReady = false;
  bool _measuring = false;

  /// True once the camera has been framed for the current set of results.
  bool _framed = false;
  String? _selectedId;

  /// How many pages of results are revealed (see kPageSize). Reset whenever
  /// the question being asked changes.
  int _page = 1;

  /// The camera keeps the user's dot in view as they move.
  bool _follow = false;

  /// The map was panned away from where results were searched; offer to search
  /// where the camera is now.
  bool _showSearchHere = false;
  LatLng? _pendingCenter;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.focusId;

    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _search.text = initial;
      // Providers can't be changed during the build/init phase.
      Future.microtask(
        () => ref.read(contractorFilterProvider.notifier).setQuery(initial),
      );
    } else {
      _search.text = ref.read(contractorFilterProvider).q;
    }
  }

  @override
  void dispose() {
    _camAc.dispose();
    _map.dispose();
    _sheet.dispose();
    _search.dispose();
    _sheetSize.dispose();
    super.dispose();
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  double get _viewportH => MediaQuery.sizeOf(context).height;

  /// The map centre that puts [point] in the middle of the part of the map the
  /// sheet leaves uncovered, rather than behind the sheet.
  LatLng _centerFor(LatLng point, double zoom, {double sheet = _mid}) {
    final cam = _map.camera;
    final p = cam.projectAtZoom(point, zoom);
    return cam.unprojectAtZoom(p + Offset(0, _viewportH * sheet / 2), zoom);
  }

  void _animateCamera(LatLng target, double zoom) {
    if (!_mapReady) return;
    final fromCenter = _map.camera.center;
    final fromZoom = _map.camera.zoom;

    _camAc.stop();
    if (_camListener != null) _camAc.removeListener(_camListener!);

    final curve = CurvedAnimation(parent: _camAc, curve: Curves.easeInOutCubic);
    _camListener = () {
      final t = curve.value;
      _map.move(
        LatLng(
          lerpDouble(fromCenter.latitude, target.latitude, t)!,
          lerpDouble(fromCenter.longitude, target.longitude, t)!,
        ),
        lerpDouble(fromZoom, zoom, t)!,
      );
    };
    _camAc
      ..duration = const Duration(milliseconds: 650)
      ..addListener(_camListener!)
      ..forward(from: 0);
  }

  /// Keeps framed points clear of everything floating over the map: the
  /// search bar + chips on top (and a pin is drawn *above* its point), the
  /// control column on the right, and the results sheet below.
  EdgeInsets _framePadding() =>
      EdgeInsets.fromLTRB(56, 235, 100, _viewportH * _mid + 40);

  /// Animate to a view that contains every point in [pts].
  void _fitPoints(List<LatLng> pts) {
    if (!_mapReady || pts.isEmpty) return;
    if (pts.length == 1) {
      _animateCamera(_centerFor(pts.first, 15), 15);
      return;
    }
    final fitted = CameraFit.coordinates(
      coordinates: pts,
      padding: _framePadding(),
      maxZoom: 16,
    ).fit(_map.camera);
    _animateCamera(fitted.center, fitted.zoom);
  }

  /// Frame the camera once per set of results: you plus the nearest few.
  ///
  /// Does nothing until the results have actually loaded; framing on "just
  /// me" would use up the one shot and never zoom out to the contractors.
  void _frameResults(List<Contractor> sorted, {required bool loaded}) {
    if (_framed || !_mapReady || !loaded) return;
    final me = _anchor();

    final focus = widget.focusId;
    if (focus != null) {
      final match = sorted.where((c) => c.id == focus && c.position != null);
      if (match.isNotEmpty) {
        _framed = true;
        _select(match.first);
        return;
      }
    }

    final nearest = [for (final c in sorted.where(_onMap).take(6)) c.position!];
    final pts = [?me, ...nearest];
    if (pts.isEmpty) return; // no position and no results: nothing to frame
    _framed = true;
    _fitPoints(pts);
  }

  void _centerOnMe() {
    final me = ref.read(locationControllerProvider).location?.latLng;
    if (me != null) _animateCamera(_centerFor(me, 15), 15);
  }

  /// First tap: go to the user (and back to searching around them). Tap again
  /// while there: follow them as they move.
  Future<void> _onMyLocationTap() async {
    if (_follow) {
      setState(() => _follow = false);
      return;
    }
    final hadCenter = ref.read(searchCenterProvider) != null;
    if (hadCenter) {
      ref.read(searchCenterProvider.notifier).reset();
      setState(() => _showSearchHere = false);
      _afterFilterChange();
    }
    await ref.read(locationControllerProvider.notifier).refresh();
    if (!mounted) return;
    _centerOnMe();
    setState(() => _follow = true);
  }

  /// Where results are being searched around: a point the user picked on the
  /// map, otherwise their own position.
  LatLng? _anchor() => ref.read(searchCenterProvider) ?? _meNow();

  /// Searches around the point the map is showing, instead of around the user.
  void _searchHere() {
    final c = _pendingCenter;
    if (c == null) return;
    HapticFeedback.selectionClick();
    ref.read(searchCenterProvider.notifier).set(c);
    setState(() {
      _follow = false;
      _showSearchHere = false;
    });
    _afterFilterChange();
  }

  /// Back to searching around the user.
  void _searchAroundMe() {
    ref.read(searchCenterProvider.notifier).reset();
    setState(() => _showSearchHere = false);
    _afterFilterChange();
    _centerOnMe();
  }

  /// The camera moved. If the user dragged it well away from where we searched,
  /// offer a search there. (Programmatic moves have no gesture, so they never
  /// trigger it, and following the user is switched off by a drag.)
  void _onCameraMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    if (_follow) setState(() => _follow = false);

    final anchor = _anchor();
    if (anchor == null) return;
    final radius = ref.read(contractorFilterProvider).radius;
    final away = haversineMeters(anchor, camera.center);
    final show = away > math.max(600.0, radius * 0.4);

    if (show != _showSearchHere || show) {
      setState(() {
        _showSearchHere = show;
        _pendingCenter = camera.center;
      });
    }
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  void _select(Contractor c) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedId = c.id;
      _follow = false; // the camera is about to go somewhere else
      // A result from ?focus= can sit past the first page; reveal it.
      final i = _ordered.indexWhere((e) => e.id == c.id);
      if (i >= _page * kPageSize) _page = (i ~/ kPageSize) + 1;
    });

    final pos = c.position;
    if (pos != null && _mapReady && _onMap(c)) {
      final me = _meNow();
      if (me != null) {
        // Keep you and them in view together: that is the point of picking
        // someone, to see how far away they are.
        _fitPoints([me, pos]);
      } else {
        final zoom = math.max(_map.camera.zoom, 15.0);
        _animateCamera(_centerFor(pos, zoom), zoom);
      }
    }

    if (_sheet.isAttached && _sheet.size < 0.3) {
      _sheet.animateTo(
        _mid,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    _scrollListTo(c);
  }

  void _scrollListTo(Contractor c) {
    final ctrl = _listCtrl;
    final index = _ordered.indexWhere((e) => e.id == c.id);
    if (ctrl == null || !ctrl.hasClients || index < 0) return;
    final target =
        _headerExtent + index * (ContractorCard.collapsedHeight + _cardGap) - 4;
    ctrl.animateTo(
      target.clamp(0.0, ctrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPinTap(Contractor c) {
    if (_measuring && c.position != null) {
      setState(() => _path.add(c.position!)); // snap to the exact contractor
    } else {
      _select(c);
    }
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  void _afterFilterChange() {
    setState(() {
      _framed = false;
      _selectedId = null;
      _page = 1;
    });
  }

  void _setType(String? type) {
    ref.read(contractorFilterProvider.notifier).setType(type);
    _afterFilterChange();
  }

  void _setStarredOnly(bool on) {
    ref.read(contractorFilterProvider.notifier).setStarredOnly(on);
    _afterFilterChange();
  }

  /// Reveal the next page, or widen the search once everything fetched is shown.
  void _seeMore(int hidden) {
    if (hidden > 0) {
      setState(() => _page++);
      return;
    }
    final next = nextRadius(ref.read(contractorFilterProvider).radius);
    if (next != null) {
      ref.read(contractorFilterProvider.notifier).setRadius(next);
      _afterFilterChange();
    }
  }

  Future<void> _toggleStar(Contractor c) async {
    HapticFeedback.selectionClick();
    try {
      final on = await ref.read(starsProvider.notifier).toggle(c);
      if (mounted) {
        AppToast.success(
          on ? context.l10n.contStarred : context.l10n.contUnstarred,
        );
      }
    } catch (_) {
      if (mounted) AppToast.error(context.l10n.contStarFailed);
    }
  }

  void _submitSearch(String q) {
    ref.read(contractorFilterProvider.notifier).setQuery(q.trim());
    FocusScope.of(context).unfocus();
    _afterFilterChange();
  }

  Future<void> _pickRadius(int current) async {
    final picked = await showRadiusSheet(context, current: current);
    if (picked == null || picked == current || !mounted) return;
    ref.read(contractorFilterProvider.notifier).setRadius(picked);
    _afterFilterChange();
  }

  // ── Measuring ─────────────────────────────────────────────────────────────

  void _toggleMeasure() => setState(() {
    _measuring = !_measuring;
    if (!_measuring) _path.clear();
  });

  void _measureFromMeTo(LatLng target) {
    final me = ref.read(locationControllerProvider).location?.latLng;
    setState(() {
      _measuring = true;
      _path
        ..clear()
        ..addAll([?me, target]);
    });
  }

  /// Asks again for the current search. Remembered searches and this
  /// session's star overlay are dropped first, so what comes back is the
  /// server's current answer and not the last two minutes' copy.
  Future<void> _refresh() async {
    if (ref.read(contractorsListProvider).isLoading) return;
    ref.read(placesRepoProvider).clearMemo();
    ref.invalidate(starsProvider);
    await runReload(
      ref,
      'contractors',
      () => ref.refresh(contractorsListProvider.future),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationControllerProvider);
    final me = loc.location?.latLng;
    final manual = loc.location?.source == LocationSource.manual;
    final filter = ref.watch(contractorFilterProvider);
    final async = ref.watch(contractorsListProvider);
    final reloading = watchReloading(ref, 'contractors');

    final center = ref.watch(searchCenterProvider);
    final anchor = center ?? me;
    ref.watch(starsProvider); // re-sort the moment a star changes

    final result = async.value;
    final all = _sortByDistance(result?.items ?? const [], me);
    // Only the first page(s): the rest wait behind "see more".
    final shown = all.take(_page * kPageSize).toList();
    final hidden = all.length - shown.length;
    _ordered = shown;
    final selectedId = shown.any((c) => c.id == _selectedId)
        ? _selectedId
        : null;
    // Pins: Google's places only go on a Google map (see map_config.dart).
    final withPos = shown.where(_onMap).toList();
    final googleServer = ref.watch(googleStatusProvider).value;

    // First fix arrives after the map is already up on the fallback centre.
    ref.listen(locationControllerProvider.select((s) => s.location != null), (
      had,
      has,
    ) {
      if (has && had != true) {
        _framed = false;
        _centerOnMe();
      }
    });
    // Following: keep the user's dot in view as they move.
    ref.listen(locationControllerProvider.select((s) => s.location?.latLng), (
      _,
      next,
    ) {
      if (_follow && next != null && _mapReady) {
        final zoom = math.max(_map.camera.zoom, 15.0);
        _animateCamera(_centerFor(next, zoom), zoom);
      }
    });
    // Reframe when results (re)load, and when the user pins a spot by hand.
    ref.listen(contractorsListProvider, (_, next) {
      final v = next.value;
      if (v != null && !next.isLoading) {
        _frameResults(_sortByDistance(v.items, _meNow()), loaded: true);
      }
    });
    ref.listen(
      locationControllerProvider.select(
        (s) => s.location?.source == LocationSource.manual ? s.location : null,
      ),
      (_, next) {
        if (next != null) _framed = false;
      },
    );

    final safe = MediaQuery.paddingOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildMap(
              me,
              anchor,
              manual,
              loc,
              filter,
              withPos,
              selectedId,
            ),
          ),

          // ── Floating top controls ───────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        _MapIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: context.l10n.commonBack,
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/home'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SearchPill(
                            controller: _search,
                            onSubmitted: _submitSearch,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        if (center != null) ...[
                          _FilterPill(
                            icon: Icons.my_location_rounded,
                            label: context.l10n.contBackToMe,
                            selected: false,
                            onTap: _searchAroundMe,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _FilterPill(
                          icon: Icons.radar_rounded,
                          label: context.l10n.distKm(
                            '${(filter.radius / 1000).round()}',
                          ),
                          selected: false,
                          onTap: () => _pickRadius(filter.radius),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          icon: Icons.apps_rounded,
                          label: context.l10n.commonAll,
                          selected: filter.type == null && !filter.starredOnly,
                          onTap: () => _setType(null),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          icon: Icons.star_rounded,
                          label: context.l10n.contFavorites,
                          selected: filter.starredOnly,
                          onTap: () => _setStarredOnly(!filter.starredOnly),
                        ),
                        for (final t in contractorTypes) ...[
                          const SizedBox(width: 8),
                          _FilterPill(
                            icon: t.icon,
                            label: t.name(context.l10n),
                            selected: filter.type == t.key,
                            onTap: () =>
                                _setType(filter.type == t.key ? null : t.key),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const LocationBanner(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  ),
                  if (_showSearchHere && !filter.starredOnly)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Center(child: _SearchHerePill(onTap: _searchHere)),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 12, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MapIconButton(
                            icon: _follow
                                ? Icons.navigation_rounded
                                : Icons.my_location_rounded,
                            tooltip: _follow
                                ? context.l10n.contStopFollow
                                : context.l10n.contMyLocation,
                            active: _follow,
                            busy: loc.resolving,
                            onTap: _onMyLocationTap,
                          ),
                          const SizedBox(height: 10),
                          _MapIconButton(
                            icon: Icons.refresh_rounded,
                            tooltip: context.l10n.refreshTooltip,
                            onTap: _refresh,
                          ),
                          const SizedBox(height: 10),
                          _MapIconButton(
                            icon: Icons.zoom_out_map_rounded,
                            tooltip: context.l10n.contFitAll,
                            onTap: () => _fitPoints([
                              ?me,
                              for (final c in withPos) c.position!,
                            ]),
                          ),
                          const SizedBox(height: 10),
                          _MapIconButton(
                            icon: Icons.straighten_rounded,
                            tooltip: _measuring
                                ? context.l10n.contMeasureOff
                                : context.l10n.contMeasure,
                            active: _measuring,
                            onTap: _toggleMeasure,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Results sheet / measure panel ───────────────────────────────────
          if (_measuring)
            Positioned(
              left: 0,
              right: 0,
              bottom: safe.bottom,
              child: MeasureCard(
                points: _path.length,
                meters: pathLengthMeters(_path),
                canStartFromMe: me != null && _path.isEmpty,
                onStartFromMe: () => setState(() => _path.add(me!)),
                onUndo: () => setState(() {
                  if (_path.isNotEmpty) _path.removeLast();
                }),
                onClear: () => setState(_path.clear),
                onDone: _toggleMeasure,
              ),
            )
          else
            Positioned.fill(
              child: _buildSheet(
                loc,
                filter,
                async,
                shown,
                hidden,
                selectedId,
                me,
                googleServer,
                reloading: reloading,
              ),
            ),
        ],
      ),
    );
  }

  LatLng? _meNow() => ref.read(locationControllerProvider).location?.latLng;

  /// Whether [c] is drawn on the map. Google's results are list-only unless
  /// the map itself is Google's (their terms: no Places content on another
  /// provider's map).
  bool _onMap(Contractor c) =>
      c.position != null && (!c.isGoogle || kUseGoogleMaps);

  /// Starred first (the people the household trusts), then nearest to the
  /// user. Distance is always from the user, even when searching elsewhere.
  List<Contractor> _sortByDistance(List<Contractor> list, LatLng? origin) {
    final stars = ref.read(starsProvider);
    bool starred(Contractor c) => stars[c.id] ?? c.starred;

    final sorted = [...list];
    sorted.sort((a, b) {
      final sa = starred(a), sb = starred(b);
      if (sa != sb) return sa ? -1 : 1;
      final da = a.distanceFrom(origin);
      final db = b.distanceFrom(origin);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return sorted;
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  Widget _buildMap(
    LatLng? me,
    LatLng? anchor,
    bool manual,
    LocationState loc,
    ContractorFilter filter,
    List<Contractor> withPos,
    String? selectedId,
  ) {
    // Brand blue for GPS; navy marks a spot you pinned by hand.
    final youColor = manual ? AppColors.deepNavy : AppColors.softBlue;

    // Selected pin last, so it draws on top of its neighbours.
    final ordered = [
      ...withPos.where((c) => c.id != selectedId),
      ...withPos.where((c) => c.id == selectedId),
    ];

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: me ?? _fallbackCenter,
        initialZoom: 14,
        minZoom: 3,
        maxZoom: 19,
        onPositionChanged: _onCameraMoved,
        onMapReady: () {
          _mapReady = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final results = ref.read(contractorsListProvider);
            _frameResults(
              _sortByDistance(results.value?.items ?? const [], _meNow()),
              loaded: results.hasValue && !results.isLoading,
            );
          });
        },
        onTap: (_, point) {
          if (_measuring) {
            setState(() => _path.add(point));
          } else if (_selectedId != null) {
            setState(() => _selectedId = null);
          }
        },
        // Pin your position by hand: handy when GPS is off, or on a simulator.
        onLongPress: (_, point) {
          HapticFeedback.mediumImpact();
          ref
              .read(locationControllerProvider.notifier)
              .setManual(point.latitude, point.longitude);
          AppToast.info(context.l10n.contPinPlaced);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _tileUrl,
          // OSM's tile policy requires an identifying user agent.
          userAgentPackageName: 'com.example.homeservice',
          tileProvider: widget.tileProvider,
          tileBuilder: (context, tile, _) =>
              ColorFiltered(colorFilter: _softTiles, child: tile),
        ),

        // Search radius (around where we are searching) and GPS accuracy
        // (around the user), drawn in real metres.
        if (anchor != null)
          CircleLayer(
            circles: [
              // The ★ view ignores distance, so there is no radius to draw.
              if (!filter.starredOnly)
                CircleMarker(
                  point: anchor,
                  radius: filter.radius.toDouble(),
                  useRadiusInMeter: true,
                  color: AppColors.softBlue.withValues(alpha: 0.07),
                  borderColor: AppColors.softBlue.withValues(alpha: 0.55),
                  borderStrokeWidth: 1.5,
                ),
              if (me != null &&
                  (loc.location?.accuracy ?? 0) > 0 &&
                  loc.location!.accuracy! < 500 &&
                  !manual)
                CircleMarker(
                  point: me,
                  radius: loc.location!.accuracy!,
                  useRadiusInMeter: true,
                  color: youColor.withValues(alpha: 0.14),
                  borderStrokeWidth: 0,
                ),
            ],
          ),

        if (_path.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: List.of(_path),
                strokeWidth: 5,
                color: AppColors.softBlue,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            for (final c in ordered)
              Marker(
                point: c.position!,
                width: 56,
                height: 60,
                alignment: Alignment.topCenter, // pin tip on the point
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Semantics(
                    button: true,
                    label: c.name,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onPinTap(c),
                      child: ContractorPin(
                        type: contractorTypeFor(c.types),
                        selected: c.id == selectedId,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        if (me != null)
          MarkerLayer(
            markers: [
              Marker(
                point: me,
                width: 64,
                height: 64,
                child: IgnorePointer(child: MyLocationDot(color: youColor)),
              ),
              // Floats just above the dot. FittedBox shrinks the label to the
              // box rather than overflowing at large text sizes. Neither
              // marker takes taps, so pins underneath stay tappable.
              Marker(
                point: me,
                width: 220,
                height: 64,
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: YouAreHereLabel(
                          text: manual
                              ? context.l10n.contPinnedSpot
                              : context.l10n.contYouAreHere,
                          color: youColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

        if (_path.isNotEmpty)
          MarkerLayer(
            markers: [
              for (var i = 0; i < _path.length; i++)
                Marker(
                  point: _path[i],
                  width: 26,
                  height: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.deepNavy,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),

        // Both ride just above the sheet so the sheet never covers them.
        ValueListenableBuilder<double>(
          valueListenable: _sheetSize,
          builder: (context, size, _) {
            final lift = _measuring
                ? 190.0
                : math.min(size, _mid) * _viewportH + 8;
            return Padding(
              padding: EdgeInsets.only(bottom: lift),
              child: const Scalebar(
                alignment: Alignment.bottomLeft,
                padding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                textStyle: TextStyle(color: Colors.black87, fontSize: 12),
                lineColor: Colors.black87,
              ),
            );
          },
        ),
        // OSM's licence requires this credit to stay visible. A compact pill
        // that rides just above the sheet, like the scale bar.
        ValueListenableBuilder<double>(
          valueListenable: _sheetSize,
          builder: (context, size, _) {
            final lift = _measuring
                ? 190.0
                : math.min(size, _mid) * _viewportH + 8;
            return Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 8, lift),
              child: Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10.5, color: Colors.black87),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Results sheet ─────────────────────────────────────────────────────────

  Widget _buildSheet(
    LocationState loc,
    ContractorFilter filter,
    AsyncValue<ContractorsResult> async,
    List<Contractor> shown,
    int hidden,
    String? selectedId,
    LatLng? me,
    PlacesServerStatus? googleServer, {
    required bool reloading,
  }) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        _sheetSize.value = n.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _sheet,
        initialChildSize: _mid,
        minChildSize: _peek,
        maxChildSize: _tall,
        snap: true,
        snapSizes: const [_peek, _mid, _tall],
        builder: (context, scroll) {
          _listCtrl = scroll;
          final bottomInset = MediaQuery.paddingOf(context).bottom;

          return DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.bgSoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: Offset(0, -4),
                  color: Color(0x22000000),
                ),
              ],
            ),
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: _SheetHeader(
                    count: shown.length + hidden,
                    loading: async.isLoading && loc.location != null,
                    showCount: loc.location != null && !async.hasError,
                    note: _googleNote(async.value, filter, googleServer),
                  ),
                ),
                ..._resultSlivers(
                  loc: loc,
                  filter: filter,
                  async: async,
                  sorted: shown,
                  hidden: hidden,
                  selectedId: selectedId,
                  me: me,
                  bottomInset: bottomInset,
                  reloading: reloading,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// One line under the sheet title about where results came from, or what
  /// to do to get Google's.
  String? _googleNote(
    ContractorsResult? r,
    ContractorFilter filter,
    PlacesServerStatus? server,
  ) {
    if (r == null) return null;

    switch (r.google) {
      case GoogleStatus.limited:
        return context.l10n.contGoogleLimited;
      case GoogleStatus.busy:
        return context.l10n.contGoogleBusy;
      case GoogleStatus.unavailable:
        return context.l10n.contGoogleDown;
      case GoogleStatus.ok:
      case GoogleStatus.off:
        break;
    }

    if (r.hasGoogleItems) {
      return kUseGoogleMaps
          ? context.l10n.contGoogleIncluded
          : context.l10n.contGoogleIncludedListOnly;
    }

    // Browsing "all" asks Google nothing. Say how to, and warn when the day's
    // allowance is nearly gone.
    if (server?.enabled == true && !filter.wantsGoogle && !filter.starredOnly) {
      final left = server!.dailyRemaining;
      if (left != null && left <= 20) {
        return context.l10n.contGoogleLeft(left);
      }
      return context.l10n.contGoogleHowTo;
    }
    return null;
  }

  List<Widget> _resultSlivers({
    required LocationState loc,
    required ContractorFilter filter,
    required AsyncValue<ContractorsResult> async,
    required List<Contractor> sorted,
    required int hidden,
    required String? selectedId,
    required LatLng? me,
    required double bottomInset,
    required bool reloading,
  }) {
    Widget fill(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );

    // The refresh button was pressed: show the loader instead of the old list.
    if (reloading) {
      return [fill(const Center(child: CircularProgressIndicator.adaptive()))];
    }

    // No position, so no query was made. Say why instead of "nothing found".
    if (loc.location == null) {
      return [
        fill(
          loc.resolving
              ? const Center(child: CircularProgressIndicator.adaptive())
              : ListEmptyState(
                  centered: true,
                  icon: Icons.location_searching_rounded,
                  title: context.l10n.contNeedLocation,
                  action: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.contLocateAgain),
                    onPressed: () =>
                        ref.read(locationControllerProvider.notifier).refresh(),
                  ),
                ),
        ),
      ];
    }

    if (async.hasError && sorted.isEmpty) {
      return [
        fill(
          ErrorState(
            icon: Icons.error_outline_rounded,
            title: context.l10n.contLoadFailed,
            error: async.error,
            onRetry: () => ref.invalidate(contractorsListProvider),
          ),
        ),
      ];
    }

    if (async.isLoading && sorted.isEmpty) {
      return [fill(const Center(child: CircularProgressIndicator.adaptive()))];
    }

    if (sorted.isEmpty) {
      if (filter.starredOnly) {
        return [
          fill(
            ListEmptyState(
              centered: true,
              icon: Icons.star_border_rounded,
              title: context.l10n.contNoFavorites,
              subtitle: context.l10n.contNoFavoritesHint,
            ),
          ),
        ];
      }
      final next = nextRadius(filter.radius);
      return [
        fill(
          ListEmptyState(
            centered: true,
            icon: Icons.search_off_rounded,
            title: context.l10n.contNoneInRadius,
            action: next == null
                ? null
                : OutlinedButton.icon(
                    icon: const Icon(Icons.expand_circle_down),
                    label: Text(context.l10n.contWidenRadius(next ~/ 1000)),
                    onPressed: () => _seeMore(0),
                  ),
          ),
        ),
      ];
    }

    // What the footer offers: more of what was fetched, then a wider search.
    final next = filter.starredOnly ? null : nextRadius(filter.radius);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        sliver: SliverList.separated(
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: _cardGap),
          itemBuilder: (_, i) {
            final c = sorted[i];
            return _ResultCard(
              contractor: c,
              me: me,
              selected: c.id == selectedId,
              onTap: () => _select(c),
              // A line drawn to a Google place on a non-Google map would be
              // Places content on that map, so it is only offered on Google's.
              onMeasure: _onMap(c) && me != null
                  ? () => _measureFromMeTo(c.position!)
                  : null,
              onToggleStar: () => _toggleStar(c),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 24),
          child: hidden > 0
              ? _FooterButton(
                  icon: Icons.expand_more_rounded,
                  label: context.l10n.contSeeMore(hidden),
                  onTap: () => _seeMore(hidden),
                )
              : next != null
              ? _FooterButton(
                  icon: Icons.radar_rounded,
                  label: context.l10n.contWidenRadius(next ~/ 1000),
                  onTap: () => _seeMore(0),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ];
  }
}

// ── Small pieces ────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.count,
    required this.loading,
    required this.showCount,
    this.note,
  });

  final int count;
  final bool loading;
  final bool showCount;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _ContractorsScreenState._headerExtent,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.contNearYou,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
                if (showCount)
                  Text(
                    context.l10n.contFound(count),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (loading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
        ],
      ),
    );
  }
}

/// One result row. A ConsumerWidget so a Google result can load its phone and
/// rating *when it is opened* (the pricier request) without the list watching
/// providers from inside a builder callback.
class _ResultCard extends ConsumerWidget {
  const _ResultCard({
    required this.contractor,
    required this.me,
    required this.selected,
    required this.onTap,
    required this.onMeasure,
    required this.onToggleStar,
  });

  final Contractor contractor;
  final LatLng? me;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onMeasure;
  final VoidCallback onToggleStar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var c = contractor;
    var loadingDetails = false;

    if (selected && c.isGoogle && c.placeId != null) {
      final details = ref.watch(placeDetailsProvider(c.placeId!));
      loadingDetails = details.isLoading;
      final d = details.value;
      if (d != null) c = c.withDetails(d);
    }

    final phone = c.phone?.trim() ?? '';
    final pos = c.position;
    final mapsUrl = c.mapsUrl;
    final website = c.website;
    // A star tapped this session wins over what the last search said.
    final starred =
        ref.watch(starsProvider.select((m) => m[c.id])) ?? c.starred;

    return ContractorCard(
      contractor: c,
      meters: c.distanceFrom(me),
      selected: selected,
      starred: starred,
      onToggleStar: onToggleStar,
      onTap: onTap,
      onCall: phone.isEmpty
          ? null
          : () => launchUrl(
              Uri(scheme: 'tel', path: phone),
              mode: LaunchMode.externalApplication,
            ),
      callLoading: loadingDetails && phone.isEmpty,
      onDirections: pos == null
          ? null
          : () => openInMaps(
              lat: pos.latitude,
              lng: pos.longitude,
              label: c.name,
              directions: true,
            ),
      onMeasure: onMeasure,
      onOpenInGoogle: c.isGoogle && mapsUrl != null
          ? () => launchUrl(
              Uri.parse(mapsUrl),
              mode: LaunchMode.externalApplication,
            )
          : null,
      onOpenWebsite: website == null
          ? null
          : () => launchUrl(
              Uri.parse(website),
              mode: LaunchMode.externalApplication,
            ),
    );
  }
}

/// "Search this area": appears after the map is dragged somewhere new.
class _SearchHerePill extends StatelessWidget {
  const _SearchHerePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softBlue,
      elevation: 4,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.travel_explore_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                context.l10n.contSearchHere,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// End-of-list action: reveal more, or search wider.
class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.softBlue,
        side: const BorderSide(color: AppColors.cardBorder),
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onSubmitted});
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 4),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: context.l10n.contSearchHint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.deepNavy,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      controller.clear();
                      onSubmitted('');
                    },
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // One tone for every pill: navy when on, brand-blue icon when off.
    final fg = selected ? Colors.white : AppColors.softBlue;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.deepNavy : Colors.white,
        elevation: selected ? 3 : 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: active ? AppColors.softBlue : Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(
                    icon,
                    size: 22,
                    color: active ? Colors.white : AppColors.deepNavy,
                  ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

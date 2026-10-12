/// Whether the contractors map is Google's.
///
/// It is **not**, yet: the screen draws OpenStreetMap, and Google's terms
/// forbid showing Places content on a non-Google map. So this is a hard `false`
/// rather than a build flag, and results that come from Google are listed but
/// never pinned (see `_onMap` in contractors_screen.dart).
///
/// Flip it only together with a Google Maps engine for that screen, never on
/// its own: with this `true` and an OSM map, Google places would be drawn on
/// OpenStreetMap.
const bool kUseGoogleMaps = false;

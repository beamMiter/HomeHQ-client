package places

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
)

const testKey = "test-key-SECRET"

// Siam Square. Points below are offsets from here.
const (
	homeLat = 13.7455
	homeLng = 100.5342
)

// ── fakes ───────────────────────────────────────────────────────────────────

type fakeStore struct {
	mu     sync.Mutex
	stars  map[string]string // place_id -> trade
	order  []string
	failOn string // "starred" makes Starred() error
}

func newFakeStore() *fakeStore { return &fakeStore{stars: map[string]string{}} }

func (f *fakeStore) Starred(_ context.Context, ids []string) (map[string]bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.failOn == "starred" {
		return nil, errors.New("db down")
	}
	out := map[string]bool{}
	for _, id := range ids {
		if _, ok := f.stars[id]; ok {
			out[id] = true
		}
	}
	return out, nil
}

func (f *fakeStore) Set(_ context.Context, placeID, trade, _ string, on bool) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if !on {
		delete(f.stars, placeID)
		for i, id := range f.order {
			if id == placeID {
				f.order = append(f.order[:i], f.order[i+1:]...)
				break
			}
		}
		return nil
	}
	existing, had := f.stars[placeID]
	if !had {
		f.order = append([]string{placeID}, f.order...) // newest first
	}
	// Mirrors PGStore: re-starring without a label keeps the one we have.
	if trade == "" {
		trade = existing
	}
	f.stars[placeID] = trade
	return nil
}

func (f *fakeStore) List(_ context.Context, limit int) ([]StarredPlace, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []StarredPlace
	for _, id := range f.order {
		if len(out) == limit {
			break
		}
		out = append(out, StarredPlace{PlaceID: id, Trade: f.stars[id]})
	}
	return out, nil
}

// fakeGoogle serves Places API (New) responses from a handler we control.
func fakeGoogle(t *testing.T, h http.HandlerFunc, opts ...func(*Limits)) (*Service, *fakeStore) {
	t.Helper()
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)

	lim := DefaultLimits()
	for _, o := range opts {
		o(&lim)
	}
	store := newFakeStore()
	return NewService(NewClient(testKey, srv.URL), store, lim), store
}

func allowAllTrades(l *Limits) { l.AllowAllTrades = true }

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}

// gp builds a Google place at (lat,lng).
func gp(id, name string, lat, lng float64, types ...string) map[string]any {
	return map[string]any{
		"id":               id,
		"displayName":      map[string]any{"text": name},
		"formattedAddress": "ที่อยู่ " + name,
		"location":         map[string]any{"latitude": lat, "longitude": lng},
		"types":            types,
	}
}

type captured struct {
	Method string
	Path   string
	Key    string
	Mask   string
	Body   searchTextRequest
}

func capture(r *http.Request) captured {
	c := captured{
		Method: r.Method,
		Path:   r.URL.Path,
		Key:    r.Header.Get("X-Goog-Api-Key"),
		Mask:   r.Header.Get("X-Goog-FieldMask"),
	}
	if r.Body != nil {
		_ = json.NewDecoder(r.Body).Decode(&c.Body)
	}
	return c
}

// ── Nearby ──────────────────────────────────────────────────────────────────

func TestNearby_SingleTrade_RequestShapeAndMapping(t *testing.T) {
	var got captured
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		got = capture(r)
		closed := gp("closed-place-1", "ปิดถาวร", homeLat+0.001, homeLng, "electrician")
		closed["businessStatus"] = "CLOSED_PERMANENTLY"
		writeJSON(w, map[string]any{"places": []any{
			gp("near-place-001", "ช่างอ้น", homeLat+0.0045, homeLng, "electrician"), // ~500 m
			gp("far-place-0001", "ไกลมาก", homeLat+0.3, homeLng, "electrician"),     // ~33 km
			closed,
			gp("", "ไม่มีไอดี", homeLat, homeLng),
		}})
	})

	out, err := svc.Nearby(context.Background(), NearbyInput{
		Lat: homeLat, Lng: homeLng, RadiusM: 5000, Trade: "electrician",
	})
	if err != nil {
		t.Fatalf("Nearby: %v", err)
	}

	if got.Method != http.MethodPost || got.Path != "/v1/places:searchText" {
		t.Errorf("wrong call: %s %s", got.Method, got.Path)
	}
	if got.Key != testKey {
		t.Errorf("api key not sent as X-Goog-Api-Key")
	}
	if got.Mask != listFieldMask {
		t.Errorf("field mask = %q, want the cheap list mask", got.Mask)
	}
	for _, expensive := range []string{"phone", "Phone", "rating", "regularOpeningHours", "websiteUri"} {
		if strings.Contains(got.Mask, expensive) {
			t.Errorf("list mask must not request %q (moves the call to a pricier SKU)", expensive)
		}
	}
	if got.Body.TextQuery != "ช่างไฟ" || got.Body.LanguageCode != "th" || got.Body.RegionCode != "TH" {
		t.Errorf("body = %+v", got.Body)
	}
	if got.Body.MaxResultCount != 20 {
		t.Errorf("maxResultCount = %d, want 20", got.Body.MaxResultCount)
	}
	c := got.Body.LocationBias
	if c == nil || math.Abs(c.Circle.Center.Latitude-homeLat) > 1e-9 || c.Circle.Radius != 5000 {
		t.Errorf("locationBias = %+v", c)
	}

	if len(out) != 1 {
		t.Fatalf("want 1 place, got %d: %+v", len(out), out)
	}
	p := out[0]
	if p.ID != "google:near-place-001" || p.PlaceID != "near-place-001" || p.Source != "google" {
		t.Errorf("ids = %q / %q / %q", p.ID, p.PlaceID, p.Source)
	}
	if len(p.Types) != 1 || p.Types[0] != "electrician" {
		t.Errorf("types = %v, want our trade key", p.Types)
	}
	if p.DistanceM < 480 || p.DistanceM > 520 {
		t.Errorf("distance = %.0f m, want ~500", p.DistanceM)
	}
	if !strings.Contains(p.MapsURL, "query_place_id=near-place-001") {
		t.Errorf("maps url = %q", p.MapsURL)
	}
	if p.Starred {
		t.Errorf("nothing is starred yet")
	}
}

func TestNearby_AllTrades_FansOutAndMergesDuplicates(t *testing.T) {
	var mu sync.Mutex
	queries := map[string]int{}

	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		c := capture(r)
		mu.Lock()
		queries[c.Body.TextQuery]++
		mu.Unlock()

		if c.Body.MaxResultCount != 10 {
			t.Errorf("fan-out maxResultCount = %d, want 10", c.Body.MaxResultCount)
		}
		switch c.Body.TextQuery {
		case "ช่างไฟ", "ช่างแอร์":
			writeJSON(w, map[string]any{"places": []any{
				gp("shared-shop-01", "ร้านช่างรวม", homeLat+0.002, homeLng),
			}})
		case "ช่างประปา":
			writeJSON(w, map[string]any{"places": []any{
				gp("plumber-000001", "ช่างประปา A", homeLat+0.001, homeLng),
			}})
		default:
			writeJSON(w, map[string]any{})
		}
	}, allowAllTrades)

	out, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 5000})
	if err != nil {
		t.Fatalf("Nearby: %v", err)
	}
	if len(queries) != 4 {
		t.Errorf("queries sent = %v, want one per trade", queries)
	}
	if len(out) != 2 || out[0].Name != "ช่างประปา A" {
		t.Fatalf("want 2 places nearest-first, got %+v", out)
	}
	shared := out[1]
	if len(shared.Types) != 2 || shared.Types[0] != "electrician" || shared.Types[1] != "hvac" {
		t.Errorf("shared shop trades = %v, want [electrician hvac]", shared.Types)
	}
}

func TestNearby_NoTradeNoText_IsRefusedWithoutCallingGoogle(t *testing.T) {
	var hits int32
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
	})

	_, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 3000})
	if !errors.Is(err, ErrQueryRequired) {
		t.Fatalf("err = %v, want ErrQueryRequired", err)
	}
	if n := atomic.LoadInt32(&hits); n != 0 {
		t.Errorf("made %d Google calls for a refused search", n)
	}
}

func TestNearby_PartialFailureKeepsWhatWorked(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		if capture(r).Body.TextQuery == "ช่างไม้" {
			http.Error(w, "boom", http.StatusInternalServerError)
			return
		}
		writeJSON(w, map[string]any{"places": []any{}})
	}, allowAllTrades)
	if _, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 3000}); err != nil {
		t.Fatalf("one failing trade must not fail the search: %v", err)
	}
}

func TestNearby_AllFail_IsUpstreamAndNeverLeaksKey(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "denied for key "+r.Header.Get("X-Goog-Api-Key"), http.StatusForbidden)
	})
	_, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 3000, Trade: "plumber"})
	if !errors.Is(err, ErrUpstream) {
		t.Fatalf("err = %v, want ErrUpstream", err)
	}
	if strings.Contains(err.Error(), testKey) {
		t.Fatalf("error leaks the api key: %v", err)
	}
}

func TestNearby_Disabled_NoKeyNeverCallsGoogle(t *testing.T) {
	var hits int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
	}))
	defer srv.Close()

	svc := NewService(NewClient("   ", srv.URL), newFakeStore(), DefaultLimits())
	if svc.Enabled() {
		t.Fatal("blank key must read as disabled")
	}
	if _, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 1000, Trade: "plumber"}); !errors.Is(err, ErrDisabled) {
		t.Errorf("Nearby err = %v, want ErrDisabled", err)
	}
	if _, err := svc.Details(context.Background(), "abcdefghij"); !errors.Is(err, ErrDisabled) {
		t.Errorf("Details err = %v, want ErrDisabled", err)
	}
	if n := atomic.LoadInt32(&hits); n != 0 {
		t.Errorf("made %d upstream calls with no key", n)
	}
}

func TestNearby_FreeTextUsesTheQueryAndClassifiesByGoogleTypes(t *testing.T) {
	var got captured
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		got = capture(r)
		writeJSON(w, map[string]any{"places": []any{
			gp("pipe-shop-0001", "ซ่อมท่อ", homeLat+0.001, homeLng, "plumber", "point_of_interest"),
			gp("mystery-0001", "ร้านทั่วไป", homeLat+0.002, homeLng, "store"),
		}})
	})

	out, err := svc.Nearby(context.Background(), NearbyInput{
		Lat: homeLat, Lng: homeLng, RadiusM: 5000, Query: "ซ่อมท่อน้ำรั่ว",
	})
	if err != nil {
		t.Fatal(err)
	}
	if got.Body.TextQuery != "ซ่อมท่อน้ำรั่ว" {
		t.Errorf("textQuery = %q", got.Body.TextQuery)
	}
	if len(out) != 2 || len(out[0].Types) != 1 || out[0].Types[0] != "plumber" {
		t.Errorf("first = %+v, want classified as plumber", out)
	}
	if len(out[1].Types) != 0 {
		t.Errorf("unknown shop types = %v, want none", out[1].Types)
	}
}

func TestNearby_ClampsRadiusToTheConfiguredCeiling(t *testing.T) {
	var got captured
	handler := func(w http.ResponseWriter, r *http.Request) {
		got = capture(r)
		writeJSON(w, map[string]any{})
	}

	svc, _ := fakeGoogle(t, handler) // default ceiling 20 km
	if _, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 9_999_999, Trade: "plumber"}); err != nil {
		t.Fatal(err)
	}
	if r := got.Body.LocationBias.Circle.Radius; r != 20000 {
		t.Errorf("radius sent = %v, want the 20 km ceiling", r)
	}

	// Raising the ceiling is possible, but never past what Google accepts.
	svc, _ = fakeGoogle(t, handler, func(l *Limits) { l.MaxRadiusM = 999_999 })
	if _, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 9_999_999, Trade: "plumber"}); err != nil {
		t.Fatal(err)
	}
	if r := got.Body.LocationBias.Circle.Radius; r != googleMaxRadiusM {
		t.Errorf("radius sent = %v, want Google's own max %v", r, googleMaxRadiusM)
	}
}

func TestNearby_ResultCountIsBounded(t *testing.T) {
	var many []any
	for i := 0; i < 60; i++ {
		many = append(many, gp(fmt.Sprintf("place-%07d", i), fmt.Sprintf("ร้าน %d", i),
			homeLat+float64(i+1)*0.0001, homeLng))
	}
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"places": many})
	})
	in := NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 5000, Trade: "plumber"}

	out, err := svc.Nearby(context.Background(), in) // no limit asked
	if err != nil {
		t.Fatal(err)
	}
	if len(out) != 20 {
		t.Errorf("default page = %d, want 20", len(out))
	}
	if out[0].Name != "ร้าน 0" {
		t.Errorf("not nearest-first: %q", out[0].Name)
	}

	in.Limit = 1000
	out, _ = svc.Nearby(context.Background(), in)
	if len(out) != 40 {
		t.Errorf("asked for 1000, got %d, want the cap of 40", len(out))
	}
}

func TestNearby_UnknownTrade(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {})
	_, err := svc.Nearby(context.Background(), NearbyInput{Lat: 1, Lng: 1, RadiusM: 1000, Trade: "astronaut"})
	if !errors.Is(err, ErrBadInput) {
		t.Fatalf("err = %v, want ErrBadInput", err)
	}
}

// ── daily budget ────────────────────────────────────────────────────────────

func TestBudget_StopsCallsAndResetsTomorrow(t *testing.T) {
	var hits int32
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		writeJSON(w, map[string]any{})
	}, func(l *Limits) { l.DailyCalls = 2 })

	day := time.Date(2026, 10, 11, 9, 0, 0, 0, time.UTC)
	svc.bud.now = func() time.Time { return day }
	in := NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 3000, Trade: "plumber"}

	for i := 0; i < 2; i++ {
		if _, err := svc.Nearby(context.Background(), in); err != nil {
			t.Fatalf("call %d: %v", i+1, err)
		}
	}
	if _, err := svc.Nearby(context.Background(), in); !errors.Is(err, ErrBudget) {
		t.Fatalf("third call err = %v, want ErrBudget", err)
	}
	if n := atomic.LoadInt32(&hits); n != 2 {
		t.Errorf("Google was called %d times, want 2 (the refused one must not go out)", n)
	}

	st := svc.Status()
	if !st.Enabled || st.DailyUsed != 2 || st.DailyLimit != 2 {
		t.Errorf("status = %+v", st)
	}

	svc.bud.now = func() time.Time { return day.Add(24 * time.Hour) }
	if _, err := svc.Nearby(context.Background(), in); err != nil {
		t.Errorf("a new day should have a fresh allowance: %v", err)
	}
}

func TestBudget_FanOutIsAllOrNothing(t *testing.T) {
	var hits int32
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		writeJSON(w, map[string]any{})
	}, allowAllTrades, func(l *Limits) { l.DailyCalls = 3 })

	// Four trades need four calls; only three are left.
	_, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 3000})
	if !errors.Is(err, ErrBudget) {
		t.Fatalf("err = %v, want ErrBudget", err)
	}
	if n := atomic.LoadInt32(&hits); n != 0 {
		t.Errorf("a refused fan-out still made %d calls", n)
	}
	if st := svc.Status(); st.DailyUsed != 0 {
		t.Errorf("refused request consumed %d of the allowance", st.DailyUsed)
	}
}

// ── details ─────────────────────────────────────────────────────────────────

func TestDetails_MapsFieldsAndUsesFullMask(t *testing.T) {
	var got captured
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		got = capture(r)
		writeJSON(w, map[string]any{
			"id":                       "near-place-001",
			"displayName":              map[string]any{"text": "ช่างอ้น"},
			"formattedAddress":         "ถนนพญาไท",
			"nationalPhoneNumber":      "081 234 5678",
			"internationalPhoneNumber": "+66 81 234 5678",
			"rating":                   4.6,
			"userRatingCount":          87,
			"websiteUri":               "https://example.test",
			"regularOpeningHours":      map[string]any{"openNow": true},
		})
	})

	d, err := svc.Details(context.Background(), "near-place-001")
	if err != nil {
		t.Fatal(err)
	}
	if got.Method != http.MethodGet || got.Path != "/v1/places/near-place-001" {
		t.Errorf("call = %s %s", got.Method, got.Path)
	}
	if got.Mask != detailsFieldMask {
		t.Errorf("mask = %q", got.Mask)
	}
	if d.Phone != "081 234 5678" || d.IntlPhone != "+66 81 234 5678" || d.Website != "https://example.test" {
		t.Errorf("contact = %+v", d)
	}
	if d.Rating == nil || *d.Rating != 4.6 || d.RatingCount == nil || *d.RatingCount != 87 {
		t.Errorf("rating = %v (%v)", d.Rating, d.RatingCount)
	}
	if d.OpenNow == nil || !*d.OpenNow {
		t.Errorf("open now = %v", d.OpenNow)
	}
}

func TestDetails_NotFound(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "nope", http.StatusNotFound)
	})
	if _, err := svc.Details(context.Background(), "missing-place-1"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

// ── stars ───────────────────────────────────────────────────────────────────

func TestStars_NearbyMarksStarredPlaces(t *testing.T) {
	svc, store := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"places": []any{
			gp("starred-shop-1", "ช่างประจำ", homeLat+0.001, homeLng),
			gp("other-shop-001", "ร้านอื่น", homeLat+0.002, homeLng),
		}})
	})
	_ = store.Set(context.Background(), "starred-shop-1", "plumber", "u1", true)

	out, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 3000, Trade: "plumber"})
	if err != nil {
		t.Fatal(err)
	}
	if !out[0].Starred || out[1].Starred {
		t.Errorf("starred flags = %v, %v; want true, false", out[0].Starred, out[1].Starred)
	}
}

func TestStars_AStoreFailureDoesNotFailTheSearch(t *testing.T) {
	svc, store := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"places": []any{gp("shop-0000001", "ร้าน", homeLat+0.001, homeLng)}})
	})
	store.failOn = "starred"

	out, err := svc.Nearby(context.Background(), NearbyInput{Lat: homeLat, Lng: homeLng, RadiusM: 3000, Trade: "plumber"})
	if err != nil || len(out) != 1 {
		t.Fatalf("out=%v err=%v; stars are an extra, not a dependency", out, err)
	}
}

func TestStars_ListFetchesBasicFieldsOnlyAndSkipsTheGone(t *testing.T) {
	var mu sync.Mutex
	masks := map[string]string{}
	svc, store := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		masks[r.URL.Path] = r.Header.Get("X-Goog-FieldMask")
		mu.Unlock()
		switch r.URL.Path {
		case "/v1/places/shop-aaaaaaaa1":
			writeJSON(w, gp("shop-aaaaaaaa1", "ใกล้", homeLat+0.001, homeLng, "electrician"))
		case "/v1/places/shop-aaaaaaaa2":
			writeJSON(w, gp("shop-aaaaaaaa2", "ไกลกว่า", homeLat+0.01, homeLng))
		default:
			http.Error(w, "gone", http.StatusNotFound) // place id no longer exists
		}
	})
	for _, s := range []StarredPlace{
		{"shop-aaaaaaaa1", ""}, {"shop-aaaaaaaa2", "plumber"}, {"shop-gone00001", "hvac"},
	} {
		_ = store.Set(context.Background(), s.PlaceID, s.Trade, "u", true)
	}

	items, skipped, err := svc.Starred(context.Background(), homeLat, homeLng)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 2 || skipped != 1 {
		t.Fatalf("items=%d skipped=%d, want 2 and 1", len(items), skipped)
	}
	if items[0].Name != "ใกล้" || !items[0].Starred {
		t.Errorf("first = %+v", items[0])
	}
	// Trade comes from our label when we have one, else from Google's types.
	if items[0].Types[0] != "electrician" || items[1].Types[0] != "plumber" {
		t.Errorf("trades = %v / %v", items[0].Types, items[1].Types)
	}
	for path, mask := range masks {
		if mask != basicDetailsFieldMask {
			t.Errorf("%s asked for %q, want only the cheap fields", path, mask)
		}
	}
}

func TestStars_NoneStarredCostsNothingEvenWithGoogleOff(t *testing.T) {
	svc := NewService(NewClient("", ""), newFakeStore(), DefaultLimits())
	items, skipped, err := svc.Starred(context.Background(), homeLat, homeLng)
	if err != nil || len(items) != 0 || skipped != 0 {
		t.Fatalf("items=%v skipped=%d err=%v", items, skipped, err)
	}
}

func TestStars_StarringWorksWithGoogleOff(t *testing.T) {
	store := newFakeStore()
	svc := NewService(NewClient("", ""), store, DefaultLimits())

	if err := svc.SetStar(context.Background(), "shop-aaaaaaaa1", "plumber", "u", true); err != nil {
		t.Fatal(err)
	}
	if _, ok := store.stars["shop-aaaaaaaa1"]; !ok {
		t.Fatal("star not stored")
	}
	if err := svc.SetStar(context.Background(), "shop-aaaaaaaa1", "", "u", false); err != nil {
		t.Fatal(err)
	}
	if len(store.stars) != 0 {
		t.Fatal("star not removed")
	}
	if err := svc.SetStar(context.Background(), "shop-aaaaaaaa1", "astronaut", "u", true); !errors.Is(err, ErrBadInput) {
		t.Errorf("unknown trade err = %v, want ErrBadInput", err)
	}
}

// ── HTTP layer ──────────────────────────────────────────────────────────────

func router(h *Handler) http.Handler {
	r := chi.NewRouter()
	r.Route("/places", h.RegisterRoutes)
	return r
}

func do(h http.Handler, method, target, body string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(method, target, strings.NewReader(body))
	h.ServeHTTP(rec, req)
	return rec
}

func get(h http.Handler, target string) *httptest.ResponseRecorder {
	return do(h, http.MethodGet, target, "")
}

func TestHandler_DisabledIs503WithStableCode(t *testing.T) {
	h := router(NewHandler(NewService(NewClient("", ""), newFakeStore(), DefaultLimits())))
	rec := get(h, "/places/nearby?lat=13.7&lng=100.5&type=plumber")
	if rec.Code != http.StatusServiceUnavailable || !strings.Contains(rec.Body.String(), "google_places_disabled") {
		t.Fatalf("got %d %s", rec.Code, rec.Body.String())
	}
}

func TestHandler_StatusAlwaysAnswers(t *testing.T) {
	off := router(NewHandler(NewService(NewClient("", ""), newFakeStore(), DefaultLimits())))
	rec := get(off, "/places/status")
	var st Status
	if rec.Code != http.StatusOK || json.Unmarshal(rec.Body.Bytes(), &st) != nil || st.Enabled {
		t.Fatalf("disabled status: %d %s", rec.Code, rec.Body.String())
	}

	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) { writeJSON(w, map[string]any{}) })
	on := router(NewHandler(svc))
	_ = get(on, "/places/nearby?lat=13.7&lng=100.5&type=plumber")
	rec = get(on, "/places/status")
	_ = json.Unmarshal(rec.Body.Bytes(), &st)
	if !st.Enabled || st.DailyUsed != 1 || st.DailyLimit != 300 {
		t.Errorf("status = %+v, want enabled, 1 of 300 used", st)
	}
}

func TestHandler_Validation(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) { writeJSON(w, map[string]any{}) })
	h := router(NewHandler(svc))

	cases := map[string]string{
		"missing lat":      "/places/nearby?lng=100.5&type=plumber",
		"lat out of range": "/places/nearby?lat=91&lng=100.5&type=plumber",
		"bad radius":       "/places/nearby?lat=13.7&lng=100.5&radius=abc&type=plumber",
		"unknown type":     "/places/nearby?lat=13.7&lng=100.5&type=astronaut",
		"no type or text":  "/places/nearby?lat=13.7&lng=100.5",
		"bad place id":     "/places/..%2Fsecret",
		"short place id":   "/places/abc",
		"starred no coord": "/places/starred",
	}
	for name, target := range cases {
		if rec := get(h, target); rec.Code != http.StatusBadRequest {
			t.Errorf("%s: got %d, want 400 (%s)", name, rec.Code, rec.Body.String())
		}
	}
}

func TestHandler_NearbyOK(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"places": []any{
			gp("near-place-001", "ช่างอ้น", homeLat+0.001, homeLng, "electrician"),
		}})
	})
	rec := get(router(NewHandler(svc)), "/places/nearby?lat=13.7455&lng=100.5342&type=electrician")
	if rec.Code != http.StatusOK {
		t.Fatalf("got %d %s", rec.Code, rec.Body.String())
	}
	var body struct {
		Items  []Place `json:"items"`
		Source string  `json:"source"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Source != "google" || len(body.Items) != 1 || body.Items[0].Name != "ช่างอ้น" {
		t.Errorf("body = %+v", body)
	}
}

func TestHandler_DailyLimitIs429WithItsOwnCode(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) { writeJSON(w, map[string]any{}) },
		func(l *Limits) { l.DailyCalls = 1 })
	h := router(NewHandler(svc))

	if rec := get(h, "/places/nearby?lat=13.7&lng=100.5&type=plumber"); rec.Code != http.StatusOK {
		t.Fatalf("first: %d", rec.Code)
	}
	rec := get(h, "/places/nearby?lat=13.7&lng=100.5&type=plumber")
	if rec.Code != http.StatusTooManyRequests || !strings.Contains(rec.Body.String(), "daily_limit") {
		t.Fatalf("second: %d %s", rec.Code, rec.Body.String())
	}
}

func TestHandler_UpstreamFailureIs502AndHidesDetail(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "quota exceeded for key "+r.Header.Get("X-Goog-Api-Key"), http.StatusTooManyRequests)
	})
	rec := get(router(NewHandler(svc)), "/places/nearby?lat=13.7&lng=100.5&type=plumber")
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("got %d", rec.Code)
	}
	if strings.Contains(rec.Body.String(), testKey) || strings.Contains(rec.Body.String(), "quota") {
		t.Errorf("response leaks upstream detail: %s", rec.Body.String())
	}
}

func TestHandler_PerUserRateLimitFollowsConfig(t *testing.T) {
	svc, _ := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) { writeJSON(w, map[string]any{}) },
		func(l *Limits) { l.RatePerMin = 3; l.DailyCalls = 0 })
	h := NewHandler(svc)
	fixed := time.Date(2026, 10, 11, 12, 0, 0, 0, time.UTC)
	h.now = func() time.Time { return fixed }
	r := router(h)

	for i := 0; i < 3; i++ {
		if rec := get(r, "/places/nearby?lat=13.7&lng=100.5&type=plumber"); rec.Code != http.StatusOK {
			t.Fatalf("request %d: got %d", i+1, rec.Code)
		}
	}
	rec := get(r, "/places/nearby?lat=13.7&lng=100.5&type=plumber")
	if rec.Code != http.StatusTooManyRequests || rec.Header().Get("Retry-After") == "" {
		t.Fatalf("over budget: got %d, Retry-After=%q", rec.Code, rec.Header().Get("Retry-After"))
	}
	if !strings.Contains(rec.Body.String(), "rate_limited") {
		t.Errorf("body = %s", rec.Body.String())
	}
}

func TestHandler_StarAndUnstar(t *testing.T) {
	svc, store := fakeGoogle(t, func(w http.ResponseWriter, r *http.Request) { writeJSON(w, map[string]any{}) })
	h := router(NewHandler(svc))

	rec := do(h, http.MethodPut, "/places/shop-aaaaaaaa1/star", `{"trade":"plumber"}`)
	if rec.Code != http.StatusOK || store.stars["shop-aaaaaaaa1"] != "plumber" {
		t.Fatalf("star: %d %s stars=%v", rec.Code, rec.Body.String(), store.stars)
	}
	// Starring twice is harmless, and the body is optional.
	if rec := do(h, http.MethodPut, "/places/shop-aaaaaaaa1/star", ""); rec.Code != http.StatusOK {
		t.Fatalf("restar: %d", rec.Code)
	}
	if store.stars["shop-aaaaaaaa1"] != "plumber" {
		t.Errorf("restarring without a trade must keep the label, got %q", store.stars["shop-aaaaaaaa1"])
	}

	if rec := do(h, http.MethodPut, "/places/shop-aaaaaaaa1/star", `{"trade":"astronaut"}`); rec.Code != http.StatusBadRequest {
		t.Errorf("unknown trade: got %d, want 400", rec.Code)
	}
	if rec := do(h, http.MethodPut, "/places/short/star", ""); rec.Code != http.StatusBadRequest {
		t.Errorf("bad id: got %d, want 400", rec.Code)
	}

	rec = do(h, http.MethodDelete, "/places/shop-aaaaaaaa1/star", "")
	if rec.Code != http.StatusOK || len(store.stars) != 0 {
		t.Fatalf("unstar: %d stars=%v", rec.Code, store.stars)
	}
}

func TestHandler_StarringDoesNotNeedGoogle(t *testing.T) {
	store := newFakeStore()
	h := router(NewHandler(NewService(NewClient("", ""), store, DefaultLimits())))
	if rec := do(h, http.MethodPut, "/places/shop-aaaaaaaa1/star", ""); rec.Code != http.StatusOK {
		t.Fatalf("got %d %s", rec.Code, rec.Body.String())
	}
}

// ── small units ─────────────────────────────────────────────────────────────

func TestLimiter_WindowResets(t *testing.T) {
	l := newLimiter(2, time.Minute)
	t0 := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	if !l.allow("u", t0) || !l.allow("u", t0) || l.allow("u", t0) {
		t.Fatal("budget of 2 not enforced")
	}
	if !l.allow("other", t0) {
		t.Fatal("users must not share a budget")
	}
	if !l.allow("u", t0.Add(61*time.Second)) {
		t.Fatal("budget should reset after the window")
	}
}

func TestLimits_Normalized(t *testing.T) {
	l := Limits{MaxRadiusM: 9e9, DefaultLimit: 500, MaxLimit: 10, DailyCalls: -5}.normalized()
	if l.MaxRadiusM != googleMaxRadiusM {
		t.Errorf("radius = %v, want Google's max", l.MaxRadiusM)
	}
	if l.DefaultLimit != 10 {
		t.Errorf("default limit = %d, must not exceed the max", l.DefaultLimit)
	}
	if l.DailyCalls != 0 || l.RatePerMin != DefaultLimits().RatePerMin {
		t.Errorf("limits = %+v", l)
	}
}

func TestHaversine(t *testing.T) {
	if d := haversineMeters(homeLat, homeLng, homeLat, homeLng); d != 0 {
		t.Errorf("same point = %v", d)
	}
	if d := haversineMeters(0, 0, 1, 0); math.Abs(d-111195) > 100 {
		t.Errorf("1° lat = %.0f m", d)
	}
}

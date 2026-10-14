package places

import (
	"context"
	"errors"
	"log"
	"math"
	"net/url"
	"sort"
	"strings"
	"sync"
)

// Trade is a kind of contractor the app searches for. Key matches the keys the
// contractors table and the client already use.
type Trade struct {
	Key   string
	Query string // Thai text query sent to Google
}

// Trades is the closed set of trades we search by. The query is plain Thai:
// Text Search understands "ช่างไฟ near here" and, unlike Nearby Search, it is
// not limited to Google's fixed type list (there is no carpenter type, for
// example).
var Trades = []Trade{
	{Key: "electrician", Query: "ช่างไฟ"},
	{Key: "plumber", Query: "ช่างประปา"},
	{Key: "carpenter", Query: "ช่างไม้"},
	{Key: "hvac", Query: "ช่างแอร์"},
}

// TradeByKey returns the trade for key, if it is one we know.
func TradeByKey(key string) (Trade, bool) {
	for _, t := range Trades {
		if t.Key == key {
			return t, true
		}
	}
	return Trade{}, false
}

const (
	minRadiusM = 100.0

	// A single search returns at most 20; when fanning out over all trades we
	// ask for fewer each so the total stays sensible.
	perSearchMax = 20
	perFanoutMax = 10

	maxQueryRunes = 100

	// How many starred places one request will look up (each is one Google
	// call) and how many at a time.
	maxStarredFetch   = 20
	starredConcurrent = 4
)

var (
	// ErrBudget means today's Google call allowance is used up.
	ErrBudget = errors.New("daily google call limit reached")

	// ErrQueryRequired means a search named neither a trade nor any text, and
	// all-trades searches are not allowed (see Limits.AllowAllTrades).
	ErrQueryRequired = errors.New("a trade or a text query is required")

	// ErrBadInput is a request the service refuses to run.
	ErrBadInput = errors.New("invalid input")
)

// Place is one business near the user, as sent to the app.
type Place struct {
	// ID is namespaced so it can never collide with a saved contractor's id.
	ID        string   `json:"id"`
	PlaceID   string   `json:"place_id"`
	Source    string   `json:"source"`
	Name      string   `json:"name"`
	Types     []string `json:"types"` // our trade keys, not Google's
	Address   string   `json:"address,omitempty"`
	Lat       float64  `json:"lat"`
	Lng       float64  `json:"lng"`
	DistanceM float64  `json:"distance_m"`
	MapsURL   string   `json:"maps_url"`
	Starred   bool     `json:"starred"`
}

// Details are the on-demand fields for one place.
type Details struct {
	PlaceID     string   `json:"place_id"`
	Name        string   `json:"name"`
	Address     string   `json:"address,omitempty"`
	Phone       string   `json:"phone,omitempty"`
	IntlPhone   string   `json:"international_phone,omitempty"`
	Rating      *float64 `json:"rating,omitempty"`
	RatingCount *int     `json:"rating_count,omitempty"`
	OpenNow     *bool    `json:"open_now,omitempty"`
	Website     string   `json:"website,omitempty"`
	MapsURL     string   `json:"maps_url"`
}

// NearbyInput is a validated search.
type NearbyInput struct {
	Lat, Lng float64
	RadiusM  float64
	Trade    string // one of Trades' keys, or "" for all
	Query    string // free text, overrides Trade's query when set
	Limit    int
}

// Status describes whether Google lookups are available and how much of
// today's allowance is left. It costs no Google call.
type Status struct {
	Enabled    bool `json:"enabled"`
	DailyUsed  int  `json:"daily_used"`
	DailyLimit int  `json:"daily_limit"`
}

// Service turns Google's responses into what the app needs.
type Service struct {
	client *Client
	store  Store
	lim    Limits
	bud    *budget
}

// NewService builds the service. store may be nil (stars are then unavailable
// and nothing is marked starred).
func NewService(c *Client, store Store, lim Limits) *Service {
	lim = lim.normalized()
	return &Service{client: c, store: store, lim: lim, bud: newBudget(lim.DailyCalls)}
}

// Enabled reports whether Google lookups are configured.
func (s *Service) Enabled() bool { return s != nil && s.client.Enabled() }

// Limits returns the effective limits.
func (s *Service) Limits() Limits { return s.lim }

// Status reports availability and today's usage.
func (s *Service) Status() Status {
	used, limit := s.bud.usage()
	return Status{Enabled: s.Enabled(), DailyUsed: used, DailyLimit: limit}
}

// Nearby finds businesses around a point, nearest first.
func (s *Service) Nearby(ctx context.Context, in NearbyInput) ([]Place, error) {
	if !s.Enabled() {
		return nil, ErrDisabled
	}
	if in.Query == "" && in.Trade == "" && !s.lim.AllowAllTrades {
		return nil, ErrQueryRequired
	}

	radius := math.Min(math.Max(in.RadiusM, minRadiusM), s.lim.MaxRadiusM)
	limit := in.Limit
	if limit <= 0 {
		limit = s.lim.DefaultLimit
	}
	if limit > s.lim.MaxLimit {
		limit = s.lim.MaxLimit
	}

	// What to ask Google, and which trade each query stands for.
	type search struct {
		query string
		trade string // "" = classify from Google's own types
		max   int
	}
	var searches []search
	switch {
	case in.Query != "":
		searches = []search{{in.Query, in.Trade, perSearchMax}}
	case in.Trade != "":
		t, ok := TradeByKey(in.Trade)
		if !ok {
			return nil, ErrBadInput
		}
		searches = []search{{t.Query, t.Key, perSearchMax}}
	default:
		for _, t := range Trades {
			searches = append(searches, search{t.Query, t.Key, perFanoutMax})
		}
	}

	// Reserve the calls up front: all or nothing, so a fan-out is never left
	// half-paid.
	if !s.bud.take(len(searches)) {
		return nil, ErrBudget
	}

	type outcome struct {
		places []googlePlace
		trade  string
		err    error
	}
	results := make([]outcome, len(searches))
	var wg sync.WaitGroup
	for i, sr := range searches {
		wg.Add(1)
		go func(i int, sr search) {
			defer wg.Done()
			ps, err := s.client.searchText(ctx, sr.query, in.Lat, in.Lng, radius, sr.max)
			results[i] = outcome{places: ps, trade: sr.trade, err: err}
		}(i, sr)
	}
	wg.Wait()

	// Partial failure is fine when fanning out; only fail if everything did.
	var firstErr error
	failed := 0
	for _, r := range results {
		if r.err != nil {
			failed++
			if firstErr == nil {
				firstErr = r.err
			}
		}
	}
	if failed == len(results) {
		return nil, firstErr
	}

	byID := map[string]*Place{}
	var order []string
	for _, r := range results {
		if r.err != nil {
			continue
		}
		for _, gp := range r.places {
			if gp.ID == "" || gp.BusinessStatus == "CLOSED_PERMANENTLY" {
				continue
			}
			d := haversineMeters(in.Lat, in.Lng, gp.Location.Latitude, gp.Location.Longitude)
			if d > radius {
				continue // bias, not restriction: drop what is outside
			}

			trade := r.trade
			if trade == "" {
				trade = tradeFromGoogleTypes(gp.Types)
			}

			if existing, ok := byID[gp.ID]; ok {
				// Same shop found by two trade queries: keep one pin, both trades.
				if trade != "" && !contains(existing.Types, trade) {
					existing.Types = append(existing.Types, trade)
				}
				continue
			}
			p := &Place{
				ID:        "google:" + gp.ID,
				PlaceID:   gp.ID,
				Source:    "google",
				Name:      gp.DisplayName.Text,
				Address:   gp.FormattedAddress,
				Lat:       gp.Location.Latitude,
				Lng:       gp.Location.Longitude,
				DistanceM: d,
				MapsURL:   mapsURL(gp.DisplayName.Text, gp.ID),
				Types:     []string{},
			}
			if trade != "" {
				p.Types = append(p.Types, trade)
			}
			byID[gp.ID] = p
			order = append(order, gp.ID)
		}
	}

	out := make([]Place, 0, len(order))
	for _, id := range order {
		out = append(out, *byID[id])
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].DistanceM < out[j].DistanceM })
	if len(out) > limit {
		out = out[:limit]
	}

	s.markStarred(ctx, out)
	return out, nil
}

// Details fetches phone, rating and opening status for one place.
func (s *Service) Details(ctx context.Context, placeID string) (*Details, error) {
	if !s.Enabled() {
		return nil, ErrDisabled
	}
	if !s.bud.take(1) {
		return nil, ErrBudget
	}
	gp, err := s.client.details(ctx, placeID, detailsFieldMask)
	if err != nil {
		return nil, err
	}
	d := &Details{
		PlaceID:     placeID,
		Name:        gp.DisplayName.Text,
		Address:     gp.FormattedAddress,
		Phone:       gp.NationalPhoneNumber,
		IntlPhone:   gp.InternationalPhoneNumber,
		Rating:      gp.Rating,
		RatingCount: gp.UserRatingCount,
		Website:     gp.WebsiteURI,
		MapsURL:     mapsURL(gp.DisplayName.Text, placeID),
	}
	if gp.RegularOpeningHours != nil {
		d.OpenNow = gp.RegularOpeningHours.OpenNow
	}
	return d, nil
}

// Starred looks up the places the household has starred, so they can be shown
// without the user having to search for them again. Only ids are stored here,
// so each one is a Google lookup (cheap fields, bounded count).
func (s *Service) Starred(ctx context.Context, lat, lng float64) (items []Place, skipped int, err error) {
	if s.store == nil {
		return []Place{}, 0, nil
	}
	stars, err := s.store.List(ctx, maxStarredFetch)
	if err != nil {
		return nil, 0, err
	}
	if len(stars) == 0 {
		return []Place{}, 0, nil
	}
	if !s.Enabled() {
		return nil, 0, ErrDisabled
	}
	if !s.bud.take(len(stars)) {
		return nil, 0, ErrBudget
	}

	type got struct {
		place *Place
		err   error
	}
	results := make([]got, len(stars))
	sem := make(chan struct{}, starredConcurrent)
	var wg sync.WaitGroup
	for i, st := range stars {
		wg.Add(1)
		go func(i int, st StarredPlace) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			gp, err := s.client.details(ctx, st.PlaceID, basicDetailsFieldMask)
			if err != nil {
				results[i] = got{err: err}
				return
			}
			if gp.BusinessStatus == "CLOSED_PERMANENTLY" {
				results[i] = got{err: ErrNotFound}
				return
			}
			trade := st.Trade
			if trade == "" {
				trade = tradeFromGoogleTypes(gp.Types)
			}
			p := &Place{
				ID:        "google:" + st.PlaceID,
				PlaceID:   st.PlaceID,
				Source:    "google",
				Name:      gp.DisplayName.Text,
				Address:   gp.FormattedAddress,
				Lat:       gp.Location.Latitude,
				Lng:       gp.Location.Longitude,
				DistanceM: haversineMeters(lat, lng, gp.Location.Latitude, gp.Location.Longitude),
				MapsURL:   mapsURL(gp.DisplayName.Text, st.PlaceID),
				Types:     []string{},
				Starred:   true,
			}
			if trade != "" {
				p.Types = append(p.Types, trade)
			}
			results[i] = got{place: p}
		}(i, st)
	}
	wg.Wait()

	items = make([]Place, 0, len(results))
	for _, r := range results {
		if r.place != nil {
			items = append(items, *r.place)
		} else {
			skipped++ // gone from Google, closed, or briefly unreachable
		}
	}
	sort.SliceStable(items, func(i, j int) bool { return items[i].DistanceM < items[j].DistanceM })
	return items, skipped, nil
}

// SetStar stars or unstars a place. It works without Google configured: it
// only touches our own table.
func (s *Service) SetStar(ctx context.Context, placeID, trade, userID string, on bool) error {
	if s.store == nil {
		return errors.New("stars are not available")
	}
	if trade != "" {
		if _, ok := TradeByKey(trade); !ok {
			return ErrBadInput
		}
	}
	return s.store.Set(ctx, placeID, trade, userID, on)
}

// markStarred sets Starred on places the household has starred. A store error
// is logged and ignored: stars are an enhancement, not a reason to fail a
// search.
func (s *Service) markStarred(ctx context.Context, places []Place) {
	if s.store == nil || len(places) == 0 {
		return
	}
	ids := make([]string, len(places))
	for i, p := range places {
		ids[i] = p.PlaceID
	}
	starred, err := s.store.Starred(ctx, ids)
	if err != nil {
		log.Printf("places: star lookup failed: %v", err)
		return
	}
	for i := range places {
		places[i].Starred = starred[places[i].PlaceID]
	}
}

// ── helpers ─────────────────────────────────────────────────────────────────

// mapsURL is the documented "Maps URLs" link that opens a place by id. Built
// locally, so it costs no extra field. query is required by the scheme; when
// query_place_id resolves it is only a fallback label.
func mapsURL(name, placeID string) string {
	if name == "" {
		name = "place"
	}
	return "https://www.google.com/maps/search/?api=1&query=" +
		url.QueryEscape(name) + "&query_place_id=" + url.QueryEscape(placeID)
}

func tradeFromGoogleTypes(types []string) string {
	for _, t := range types {
		switch t {
		case "electrician":
			return "electrician"
		case "plumber":
			return "plumber"
		case "hvac_contractor":
			return "hvac"
		}
	}
	return ""
}

func contains(xs []string, v string) bool {
	for _, x := range xs {
		if x == v {
			return true
		}
	}
	return false
}

// haversineMeters uses the same earth radius as the contractors SQL, so a
// distance from Google and one from our own database are comparable.
func haversineMeters(lat1, lng1, lat2, lng2 float64) float64 {
	const earthRadiusM = 6371000.0
	rad := func(d float64) float64 { return d * math.Pi / 180 }
	dLat := rad(lat2 - lat1)
	dLng := rad(lng2 - lng1)
	h := math.Pow(math.Sin(dLat/2), 2) +
		math.Cos(rad(lat1))*math.Cos(rad(lat2))*math.Pow(math.Sin(dLng/2), 2)
	// Clamp: floating-point error can push h a hair above 1.
	return 2 * earthRadiusM * math.Asin(math.Min(1, math.Sqrt(h)))
}

// cleanQuery trims a free-text query and bounds its length.
func cleanQuery(q string) string {
	q = strings.TrimSpace(q)
	r := []rune(q)
	if len(r) > maxQueryRunes {
		q = string(r[:maxQueryRunes])
	}
	return q
}

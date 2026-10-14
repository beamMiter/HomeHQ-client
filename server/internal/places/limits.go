package places

import (
	"sync"
	"time"
)

// Limits are the knobs that keep Google traffic (and its bill) bounded.
//
// The defaults suit one household: a handful of people, searching a few times
// a day. They are all overridable by environment so the same binary can serve
// a bigger audience later without code changes.
type Limits struct {
	// DailyCalls caps outbound Google calls per day across all users. This is
	// the backstop against a runaway bill. 0 means unlimited.
	DailyCalls int

	// RatePerMin caps requests per signed-in user per minute.
	RatePerMin int

	// MaxRadiusM is the largest search radius accepted. Google allows 50 km;
	// a neighbourhood search rarely needs more than 20.
	MaxRadiusM float64

	// DefaultLimit / MaxLimit bound how many results one search returns.
	DefaultLimit int
	MaxLimit     int

	// AllowAllTrades permits a search with neither a trade nor text. That fans
	// out into one Google call per trade, so it is off by default: the app asks
	// for a trade (one call) or saved/starred places (no Google call at all).
	AllowAllTrades bool
}

// DefaultLimits returns the private-household defaults.
func DefaultLimits() Limits {
	return Limits{
		DailyCalls:   300,
		RatePerMin:   20,
		MaxRadiusM:   20000,
		DefaultLimit: 20,
		MaxLimit:     40,
	}
}

// normalized fills zero values and clamps to what Google accepts.
func (l Limits) normalized() Limits {
	d := DefaultLimits()
	if l.RatePerMin <= 0 {
		l.RatePerMin = d.RatePerMin
	}
	if l.MaxRadiusM <= 0 {
		l.MaxRadiusM = d.MaxRadiusM
	}
	if l.MaxRadiusM > googleMaxRadiusM {
		l.MaxRadiusM = googleMaxRadiusM
	}
	if l.DefaultLimit <= 0 {
		l.DefaultLimit = d.DefaultLimit
	}
	if l.MaxLimit <= 0 {
		l.MaxLimit = d.MaxLimit
	}
	if l.DefaultLimit > l.MaxLimit {
		l.DefaultLimit = l.MaxLimit
	}
	if l.DailyCalls < 0 {
		l.DailyCalls = 0
	}
	return l
}

// budget counts outbound Google calls per calendar day.
//
// It lives in memory, so a restart resets it. That is acceptable as a
// backstop; if this ever has to be a hard financial limit across several
// instances, move the counter into the database.
type budget struct {
	mu    sync.Mutex
	limit int
	day   string
	used  int
	now   func() time.Time
	loc   *time.Location
}

func newBudget(limit int) *budget {
	loc, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		loc = time.Local
	}
	return &budget{limit: limit, now: time.Now, loc: loc}
}

func (b *budget) rollover() {
	today := b.now().In(b.loc).Format("2006-01-02")
	if today != b.day {
		b.day = today
		b.used = 0
	}
}

// take reserves n calls, all or nothing. It reports false when that would go
// over today's limit.
func (b *budget) take(n int) bool {
	if b.limit <= 0 || n <= 0 {
		return true
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.rollover()
	if b.used+n > b.limit {
		return false
	}
	b.used += n
	return true
}

// usage returns calls used today and the limit (0 = unlimited).
func (b *budget) usage() (used, limit int) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.rollover()
	return b.used, b.limit
}

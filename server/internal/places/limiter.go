package places

import (
	"sync"
	"time"
)

// limiter is a small fixed-window rate limiter keyed by user.
//
// Every request here can cost money, so each signed-in user gets a modest
// budget per window. It is in-process: with several API instances each has its
// own counters, which is still a hard ceiling per instance.
type limiter struct {
	mu     sync.Mutex
	max    int
	window time.Duration
	m      map[string]*bucket
}

type bucket struct {
	start time.Time
	n     int
}

func newLimiter(max int, window time.Duration) *limiter {
	return &limiter{max: max, window: window, m: map[string]*bucket{}}
}

// allow records one request for key and reports whether it is within budget.
func (l *limiter) allow(key string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	// Keep the map from growing without bound.
	if len(l.m) > 10000 {
		for k, b := range l.m {
			if now.Sub(b.start) >= l.window {
				delete(l.m, k)
			}
		}
	}

	b, ok := l.m[key]
	if !ok || now.Sub(b.start) >= l.window {
		l.m[key] = &bucket{start: now, n: 1}
		return true
	}
	if b.n >= l.max {
		return false
	}
	b.n++
	return true
}

package cameras

import (
	"context"
	"regexp"
	"sync"
	"time"
)

// cache lifetimes: short, so a refresh feels live but the grid doesn't make a
// vendor call for every camera on every open.
const (
	listTTL     = 60 * time.Second
	snapshotTTL = 20 * time.Second
	liveTTL     = 30 * time.Second
	maxCacheLen = 64
)

// idPattern: Imou device ids are short alphanumeric strings.
var idPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{4,64}$`)

// Status is what the app learns before it asks for any camera.
type Status struct {
	Enabled bool   `json:"enabled"`
	Driver  string `json:"driver,omitempty"`
}

// Service adds caching, limits and checks in front of a Driver.
type Service struct {
	drv Driver // nil = off
	now func() time.Time

	mu   sync.Mutex
	list struct {
		at    time.Time
		items []Camera
	}
	snaps map[string]snapEntry
	lives map[string]liveEntry
}

type snapEntry struct {
	at  time.Time
	img Image
}

type liveEntry struct {
	at   time.Time
	live Live
}

// NewService wraps drv (nil switches the feature off).
func NewService(drv Driver) *Service {
	return &Service{
		drv:   drv,
		now:   time.Now,
		snaps: map[string]snapEntry{},
		lives: map[string]liveEntry{},
	}
}

func (s *Service) Enabled() bool { return s != nil && s.drv != nil }

func (s *Service) Status() Status {
	if !s.Enabled() {
		return Status{}
	}
	return Status{Enabled: true, Driver: s.drv.Name()}
}

// List returns the cameras, from a short-lived cache when possible.
func (s *Service) List(ctx context.Context) ([]Camera, error) {
	if !s.Enabled() {
		return nil, ErrDisabled
	}
	s.mu.Lock()
	if s.list.items != nil && s.now().Sub(s.list.at) < listTTL {
		items := append([]Camera(nil), s.list.items...)
		s.mu.Unlock()
		return items, nil
	}
	s.mu.Unlock()

	items, err := s.drv.List(ctx)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	s.list.items = append([]Camera(nil), items...)
	s.list.at = s.now()
	s.mu.Unlock()
	return items, nil
}

// Refresh drops the cached list and snapshots, so the next call hits the vendor.
func (s *Service) Refresh() {
	s.mu.Lock()
	s.list.items = nil
	s.snaps = map[string]snapEntry{}
	s.lives = map[string]liveEntry{}
	s.mu.Unlock()
}

// camera returns a camera from the cached list, if it is there.
func (s *Service) camera(id string) (Camera, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range s.list.items {
		if c.ID == id {
			return c, true
		}
	}
	return Camera{}, false
}

// ensureCamera finds a camera, loading the list once if it isn't cached.
func (s *Service) ensureCamera(ctx context.Context, id string) (Camera, error) {
	if c, ok := s.camera(id); ok {
		return c, nil
	}
	if _, err := s.List(ctx); err != nil {
		return Camera{}, err
	}
	if c, ok := s.camera(id); ok {
		return c, nil
	}
	return Camera{}, ErrNotFound
}

// known reports (online, found) from the cached list, without calling out.
func (s *Service) known(id string) (online, found bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range s.list.items {
		if c.ID == id {
			return c.Online, true
		}
	}
	return false, false
}

func (s *Service) check(id string) error {
	if !s.Enabled() {
		return ErrDisabled
	}
	if !idPattern.MatchString(id) {
		return ErrBadInput
	}
	// A camera already known to be offline costs no vendor call.
	if online, found := s.known(id); found && !online {
		return ErrOffline
	}
	return nil
}

// Live returns where to play a camera from.
func (s *Service) Live(ctx context.Context, id string, q Quality) (Live, error) {
	if err := s.check(id); err != nil {
		return Live{}, err
	}
	key := id + "|" + string(q)
	s.mu.Lock()
	if e, ok := s.lives[key]; ok && s.now().Sub(e.at) < liveTTL {
		s.mu.Unlock()
		return e.live, nil
	}
	s.mu.Unlock()

	l, err := s.drv.Live(ctx, id, q)
	if err != nil {
		return Live{}, err
	}
	s.mu.Lock()
	if len(s.lives) >= maxCacheLen {
		s.lives = map[string]liveEntry{}
	}
	s.lives[key] = liveEntry{at: s.now(), live: l}
	s.mu.Unlock()
	return l, nil
}

// Snapshot returns a still picture, reused for a few seconds.
func (s *Service) Snapshot(ctx context.Context, id string) (Image, error) {
	if err := s.check(id); err != nil {
		return Image{}, err
	}
	s.mu.Lock()
	if e, ok := s.snaps[id]; ok && s.now().Sub(e.at) < snapshotTTL {
		s.mu.Unlock()
		return e.img, nil
	}
	s.mu.Unlock()

	img, err := s.drv.Snapshot(ctx, id)
	if err != nil {
		return Image{}, err
	}
	s.mu.Lock()
	if len(s.snaps) >= maxCacheLen {
		s.snaps = map[string]snapEntry{}
	}
	s.snaps[id] = snapEntry{at: s.now(), img: img}
	s.mu.Unlock()
	return img, nil
}

// PTZ turns the camera head. d is clamped to [MinPTZDuration, MaxPTZDuration]
// (0 means DefaultPTZDuration); "stop" ignores it.
func (s *Service) PTZ(ctx context.Context, id string, a PTZAction, d time.Duration) error {
	if err := s.check(id); err != nil {
		return err
	}
	if c, ok := s.camera(id); ok {
		if !c.PTZ || (a.IsZoom() && !c.Zoom) {
			return ErrUnsupported
		}
	}
	switch {
	case d <= 0:
		d = DefaultPTZDuration
	case d < MinPTZDuration:
		d = MinPTZDuration
	case d > MaxPTZDuration:
		d = MaxPTZDuration
	}
	return s.drv.PTZ(ctx, id, a, d)
}

// SwitchStates reads every setting this camera supports.
func (s *Service) SwitchStates(ctx context.Context, id string) (map[string]bool, error) {
	if err := s.check(id); err != nil {
		return nil, err
	}
	c, err := s.ensureCamera(ctx, id)
	if err != nil {
		return nil, err
	}
	out := make(map[string]bool, len(c.Switches))
	for _, name := range c.Switches {
		k, ok := ParseSwitchKey(name)
		if !ok {
			continue
		}
		on, err := s.drv.Switch(ctx, id, k)
		if err != nil {
			return nil, err
		}
		out[name] = on
	}
	return out, nil
}

// SetSwitch changes one setting, if the camera has it.
func (s *Service) SetSwitch(ctx context.Context, id string, k SwitchKey, on bool) error {
	if err := s.check(id); err != nil {
		return err
	}
	c, err := s.ensureCamera(ctx, id)
	if err != nil {
		return err
	}
	supported := false
	for _, name := range c.Switches {
		if name == string(k) {
			supported = true
		}
	}
	if !supported {
		return ErrUnsupported
	}
	return s.drv.SetSwitch(ctx, id, k, on)
}

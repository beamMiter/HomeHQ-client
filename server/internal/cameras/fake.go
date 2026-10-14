package cameras

import (
	"bytes"
	"context"
	"fmt"
	"hash/fnv"
	"image"
	"image/color"
	"image/png"
	"sync"
	"time"
)

// DefaultFakeStreamURL is Apple's public HLS test stream, so the player can be
// exercised end to end without any camera.
const DefaultFakeStreamURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"

// Fake is a Driver with a few made-up cameras, for UI work and tests.
type Fake struct {
	StreamURL string

	// Pictures makes Snapshot draw a made-up frame. Off, the cameras have no
	// still picture (ErrUnsupported), which is what the app shows with a camera
	// icon on the cover, as it would for a camera that cannot take one.
	Pictures bool

	mu       sync.Mutex
	moves    []string
	switches map[string]bool
}

func NewFake(streamURL string) *Fake {
	if streamURL == "" {
		streamURL = DefaultFakeStreamURL
	}
	return &Fake{StreamURL: streamURL, Pictures: true, switches: map[string]bool{}}
}

func (f *Fake) Name() string { return "fake" }

// The demo set covers the cases the UI has to handle: a camera that turns and
// has every setting, one that only has detection settings, and one offline.
var fakeCameras = []Camera{
	{
		ID: "FAKE-FRONT-DOOR", Name: "Front door", Model: "Demo", Online: true,
		HumanDetect: true, PTZ: true, Zoom: true,
		Switches: []string{"privacy", "motion", "human", "light", "light_auto"},
	},
	{
		ID: "FAKE-PARCEL-SPOT", Name: "Parcel spot", Model: "Demo", Online: true,
		HumanDetect: true, Switches: []string{"motion", "human", "light"},
	},
	{ID: "FAKE-BACK-YARD", Name: "Back yard", Model: "Demo", Online: false, Switches: []string{}},
}

func (f *Fake) find(id string) (Camera, error) {
	for _, c := range fakeCameras {
		if c.ID == id {
			return c, nil
		}
	}
	return Camera{}, ErrNotFound
}

func (f *Fake) List(context.Context) ([]Camera, error) {
	return append([]Camera(nil), fakeCameras...), nil
}

func (f *Fake) Live(_ context.Context, id string, q Quality) (Live, error) {
	c, err := f.find(id)
	if err != nil {
		return Live{}, err
	}
	if !c.Online {
		return Live{}, ErrOffline
	}
	return Live{URL: f.StreamURL, Protocol: "hls", Quality: q}, nil
}

// PTZ records the move ("<id> <action> <ms>") so tests can see what was sent.
func (f *Fake) PTZ(_ context.Context, id string, a PTZAction, d time.Duration) error {
	c, err := f.find(id)
	if err != nil {
		return err
	}
	if !c.Online {
		return ErrOffline
	}
	if !c.PTZ {
		return ErrUnsupported
	}
	f.mu.Lock()
	f.moves = append(f.moves, fmt.Sprintf("%s %s %d", id, a, d.Milliseconds()))
	f.mu.Unlock()
	return nil
}

// Moves returns the recorded PTZ moves.
func (f *Fake) Moves() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.moves...)
}

func (f *Fake) Switch(_ context.Context, id string, k SwitchKey) (bool, error) {
	if _, err := f.find(id); err != nil {
		return false, err
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if v, ok := f.switches[id+"/"+string(k)]; ok {
		return v, nil
	}
	// Detection starts on; privacy and the light start off, like a camera out
	// of the box.
	return k == SwitchMotion || k == SwitchHuman, nil
}

func (f *Fake) SetSwitch(_ context.Context, id string, k SwitchKey, on bool) error {
	if _, err := f.find(id); err != nil {
		return err
	}
	f.mu.Lock()
	f.switches[id+"/"+string(k)] = on
	f.mu.Unlock()
	return nil
}

// Snapshot draws a flat, per-camera coloured frame with a lighter band, so the
// grid shows distinct pictures.
func (f *Fake) Snapshot(_ context.Context, id string) (Image, error) {
	c, err := f.find(id)
	if err != nil {
		return Image{}, err
	}
	if !c.Online {
		return Image{}, ErrOffline
	}
	if !f.Pictures {
		return Image{}, ErrUnsupported
	}
	h := fnv.New32a()
	_, _ = h.Write([]byte(id))
	seed := h.Sum32()
	base := color.RGBA{R: uint8(40 + seed%80), G: uint8(60 + (seed>>8)%80), B: uint8(100 + (seed>>16)%100), A: 255}

	const w, hgt = 640, 360
	img := image.NewRGBA(image.Rect(0, 0, w, hgt))
	for y := 0; y < hgt; y++ {
		for x := 0; x < w; x++ {
			c := base
			if y > hgt*2/3 { // "floor"
				c = color.RGBA{R: base.R / 2, G: base.G / 2, B: base.B / 2, A: 255}
			}
			if x > w/3 && x < w/3+120 && y > hgt/3 && y < hgt*2/3 { // a "doorway"
				c = color.RGBA{R: 230, G: 235, B: 245, A: 255}
			}
			img.SetRGBA(x, y, c)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return Image{}, err
	}
	return Image{Data: buf.Bytes(), ContentType: "image/png"}, nil
}

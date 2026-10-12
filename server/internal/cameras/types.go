// Package cameras shows the household's cameras in the app.
//
// The video itself stays with the camera vendor (Imou keeps the recordings, as
// before); this package only asks the vendor's cloud for a live stream address
// and a still picture, and hands those to the app. A Driver hides which vendor
// that is, so a fake one serves the UI and tests before any camera is wired up.
package cameras

import (
	"context"
	"errors"
	"time"
)

// Quality is the stream profile the app asks for.
type Quality string

const (
	QualityHD Quality = "hd"
	QualitySD Quality = "sd"
)

// ParseQuality accepts "", "hd" or "sd" (empty means HD).
func ParseQuality(s string) (Quality, bool) {
	switch s {
	case "", "hd":
		return QualityHD, true
	case "sd":
		return QualitySD, true
	}
	return "", false
}

// Camera is one camera as the app sees it.
type Camera struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Model string `json:"model,omitempty"`

	// Online is whether the vendor's cloud can currently reach the camera.
	Online bool `json:"online"`

	// HumanDetect is true when the camera reports it can detect people itself.
	HumanDetect bool `json:"human_detect"`

	// PTZ: the camera can be turned (pan/tilt). Zoom: it has an optical zoom.
	PTZ  bool `json:"ptz"`
	Zoom bool `json:"zoom"`

	// Switches lists the on/off settings this camera supports (SwitchKey
	// values), so the app shows only controls that will work.
	Switches []string `json:"switches"`
}

// PTZAction is one thing the camera head can be told to do.
type PTZAction string

const (
	PTZUp        PTZAction = "up"
	PTZDown      PTZAction = "down"
	PTZLeft      PTZAction = "left"
	PTZRight     PTZAction = "right"
	PTZUpLeft    PTZAction = "up_left"
	PTZUpRight   PTZAction = "up_right"
	PTZDownLeft  PTZAction = "down_left"
	PTZDownRight PTZAction = "down_right"
	PTZZoomIn    PTZAction = "zoom_in"
	PTZZoomOut   PTZAction = "zoom_out"
	PTZStop      PTZAction = "stop"
)

var ptzActions = map[PTZAction]bool{
	PTZUp: true, PTZDown: true, PTZLeft: true, PTZRight: true,
	PTZUpLeft: true, PTZUpRight: true, PTZDownLeft: true, PTZDownRight: true,
	PTZZoomIn: true, PTZZoomOut: true, PTZStop: true,
}

// ParsePTZAction validates an action name from the app.
func ParsePTZAction(s string) (PTZAction, bool) {
	a := PTZAction(s)
	return a, ptzActions[a]
}

// IsZoom reports whether the action needs an optical zoom.
func (a PTZAction) IsZoom() bool { return a == PTZZoomIn || a == PTZZoomOut }

// SwitchKey names an on/off camera setting.
type SwitchKey string

const (
	// SwitchPrivacy turns the camera's view off (privacy mode).
	SwitchPrivacy SwitchKey = "privacy"
	// SwitchMotion is the camera's own motion detection.
	SwitchMotion SwitchKey = "motion"
	// SwitchHuman is the camera's own person detection.
	SwitchHuman SwitchKey = "human"
	// SwitchLight is the camera's built-in light (spotlight).
	SwitchLight SwitchKey = "light"
	// SwitchLightAuto turns that light on by itself when something moves.
	SwitchLightAuto SwitchKey = "light_auto"
)

// ParseSwitchKey validates a switch name from the app.
func ParseSwitchKey(s string) (SwitchKey, bool) {
	switch k := SwitchKey(s); k {
	case SwitchPrivacy, SwitchMotion, SwitchHuman, SwitchLight, SwitchLightAuto:
		return k, true
	}
	return "", false
}

// PTZ move durations: long enough to be visible, short enough that a lost
// "stop" can't leave the camera swinging.
const (
	MinPTZDuration     = 100 * time.Millisecond
	DefaultPTZDuration = 500 * time.Millisecond
	MaxPTZDuration     = 3 * time.Second
)

// Live is where the app should play a camera from.
type Live struct {
	URL      string  `json:"url"`
	Protocol string  `json:"protocol"` // "hls"
	Quality  Quality `json:"quality"`
}

// Image is a still picture.
type Image struct {
	Data        []byte
	ContentType string
}

// Driver is a camera source: a vendor cloud, or a fake.
type Driver interface {
	Name() string
	List(ctx context.Context) ([]Camera, error)
	Live(ctx context.Context, id string, q Quality) (Live, error)
	Snapshot(ctx context.Context, id string) (Image, error)

	// PTZ moves the camera head for d (ignored for PTZStop).
	PTZ(ctx context.Context, id string, a PTZAction, d time.Duration) error
	// Switch reads an on/off setting; SetSwitch changes it.
	Switch(ctx context.Context, id string, k SwitchKey) (bool, error)
	SetSwitch(ctx context.Context, id string, k SwitchKey, on bool) error
}

var (
	// ErrDisabled: no camera source is configured.
	ErrDisabled = errors.New("cameras: not configured")
	// ErrProviderLimit: the camera cloud itself refused, because its own call
	// allowance is used up. (There is no limit on our side.)
	ErrProviderLimit = errors.New("cameras: the camera cloud's call limit is reached")
	// ErrBadInput: the request itself is wrong (bad id, bad quality).
	ErrBadInput = errors.New("cameras: bad input")
	// ErrNotFound: the vendor doesn't know this camera.
	ErrNotFound = errors.New("cameras: camera not found")
	// ErrOffline: the camera can't be reached right now.
	ErrOffline = errors.New("cameras: camera offline")
	// ErrConfig: the credentials are wrong or rejected; fix the server config.
	ErrConfig = errors.New("cameras: credentials rejected")
	// ErrUnsupported: this camera doesn't have that capability.
	ErrUnsupported = errors.New("cameras: not supported by this camera")
)

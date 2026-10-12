package cameras

import (
	"bytes"
	"context"
	"crypto/md5"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

// DefaultImouBaseURL is the endpoint the open-source `imouapi` client uses.
// Accounts registered in another region need their own host (IMOU_BASE_URL).
const DefaultImouBaseURL = "https://openapi.easy4ip.com/openapi"

// regionBaseURLs maps IMOU_REGION shortcuts to hosts. Only the one the Home
// Assistant docs name is listed; anything else is set with IMOU_BASE_URL.
var regionBaseURLs = map[string]string{
	"sg": "https://openapi-sg.easy4ip.com/openapi",
}

// ImouConfig holds the Imou Open Platform credentials.
type ImouConfig struct {
	AppID     string
	AppSecret string
	// BaseURL overrides the host. Empty = region default, else DefaultImouBaseURL.
	BaseURL string
	Region  string
	// SnapshotWait is how long to wait after asking for a snapshot before
	// downloading it (the picture isn't ready at once). 0 = 1.5 s.
	SnapshotWait time.Duration
}

// Imou is a Driver backed by the Imou Open Platform cloud API.
//
// Protocol notes (from the open-source `imouapi` client, not Imou's own docs,
// so verify against open.imoulife.com before relying on edge cases):
//   - POST {base}/{method}, body {"system":{ver,sign,appId,time,nonce},
//     "params":{...,"token"},"id"}; sign = md5("time:{t},nonce:{n},appSecret:{s}")
//   - reply {"result":{"code":"0","msg":"","data":{...}}}; "0" is success
//   - accessToken first; TK1002 means the token expired, so fetch and retry
type Imou struct {
	cfg  ImouConfig
	base string
	http *http.Client
	now  func() time.Time

	mu       sync.Mutex
	token    string
	tokenExp time.Time
}

// NewImou builds the driver.
func NewImou(cfg ImouConfig) *Imou {
	base := strings.TrimRight(cfg.BaseURL, "/")
	if base == "" {
		base = regionBaseURLs[strings.ToLower(cfg.Region)]
	}
	if base == "" {
		base = DefaultImouBaseURL
	}
	if cfg.SnapshotWait <= 0 {
		cfg.SnapshotWait = 1500 * time.Millisecond
	}
	return &Imou{
		cfg:  cfg,
		base: base,
		http: &http.Client{Timeout: 15 * time.Second},
		now:  time.Now,
	}
}

func (c *Imou) Name() string { return "imou" }

// APIError is a non-success answer from Imou.
type APIError struct {
	Method string
	Code   string
	Msg    string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("imou %s: %s %s", e.Method, e.Code, e.Msg)
}

// Codes the open-source client treats specially.
const (
	codeOK            = "0"
	codeTokenExpired  = "TK1002"
	codeBadAppID      = "OP1008"
	codeBadAppID2     = "SN1001"
	codeNotAuthorized = "OP1009"
	codeCallLimit     = "OP1013" // "Call interface times exceed limit": Imou's own allowance
	codeLiveNone      = "LV1002" // no live stream exists yet
	codeLiveExists    = "LV1001" // a live stream already exists
)

// maxTokenAge bounds how long a token is trusted even if Imou's expiry field
// is read wrongly; a stale token is also recovered via TK1002.
const maxTokenAge = 12 * time.Hour

func (c *Imou) sign(ts int64, nonce string) string {
	sum := md5.Sum([]byte(fmt.Sprintf("time:%d,nonce:%s,appSecret:%s", ts, nonce, c.cfg.AppSecret)))
	return hex.EncodeToString(sum[:])
}

func randToken(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

type envelope struct {
	Result struct {
		Code any             `json:"code"`
		Msg  string          `json:"msg"`
		Data json.RawMessage `json:"data"`
	} `json:"result"`
}

// ensureToken returns a valid access token, fetching one if needed.
func (c *Imou) ensureToken(ctx context.Context) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.token != "" && c.now().Before(c.tokenExp) {
		return c.token, nil
	}
	var data struct {
		AccessToken string `json:"accessToken"`
		ExpireTime  any    `json:"expireTime"`
	}
	if err := c.post(ctx, "accessToken", nil, "", &data); err != nil {
		return "", err
	}
	if data.AccessToken == "" {
		return "", &APIError{Method: "accessToken", Code: "empty", Msg: "no accessToken in reply"}
	}
	c.token = data.AccessToken
	c.tokenExp = c.now().Add(tokenLifetime(data.ExpireTime, c.now()))
	return c.token, nil
}

// tokenLifetime reads expireTime defensively: seconds from now, or an absolute
// Unix time; either way never more than maxTokenAge, and not less than a minute.
func tokenLifetime(v any, now time.Time) time.Duration {
	var n float64
	switch t := v.(type) {
	case float64:
		n = t
	case string:
		f, err := strconv.ParseFloat(t, 64)
		if err != nil {
			return maxTokenAge
		}
		n = f
	default:
		return maxTokenAge
	}
	d := time.Duration(n) * time.Second
	if n > 1e9 { // looks like an absolute Unix timestamp
		d = time.Unix(int64(n), 0).Sub(now)
	}
	if d > maxTokenAge {
		d = maxTokenAge
	}
	if d < time.Minute {
		d = time.Minute
	}
	return d
}

func (c *Imou) dropToken() {
	c.mu.Lock()
	c.token = ""
	c.mu.Unlock()
}

// call runs one API method with the token, retrying once if it expired.
func (c *Imou) call(ctx context.Context, method string, params map[string]any, out any) error {
	for attempt := 0; ; attempt++ {
		tok, err := c.ensureToken(ctx)
		if err != nil {
			return err
		}
		err = c.post(ctx, method, params, tok, out)
		var ae *APIError
		if attempt == 0 && errors.As(err, &ae) && ae.Code == codeTokenExpired {
			c.dropToken()
			continue
		}
		return err
	}
}

// post sends one request and decodes result.data into out.
func (c *Imou) post(ctx context.Context, method string, params map[string]any, token string, out any) error {
	if c.cfg.AppID == "" || c.cfg.AppSecret == "" {
		return ErrDisabled
	}
	p := map[string]any{}
	for k, v := range params {
		p[k] = v
	}
	if token != "" {
		p["token"] = token
	}
	ts := c.now().Unix()
	nonce := randToken(16)
	body, err := json.Marshal(map[string]any{
		"system": map[string]any{
			"ver":   "1.0",
			"sign":  c.sign(ts, nonce),
			"appId": c.cfg.AppID,
			"time":  ts,
			"nonce": nonce,
		},
		"params": p,
		"id":     randToken(6),
	})
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.base+"/"+method, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode != http.StatusOK {
		return &APIError{Method: method, Code: "http_" + strconv.Itoa(resp.StatusCode), Msg: truncate(string(raw), 200)}
	}

	var env envelope
	if err := json.Unmarshal(raw, &env); err != nil {
		return &APIError{Method: method, Code: "bad_json", Msg: err.Error()}
	}
	code := codeString(env.Result.Code)
	if code != codeOK {
		switch code {
		case codeBadAppID, codeBadAppID2, codeNotAuthorized:
			return fmt.Errorf("%w: %w", ErrConfig, &APIError{Method: method, Code: code, Msg: env.Result.Msg})
		case codeCallLimit:
			return fmt.Errorf("%w: %w", ErrProviderLimit, &APIError{Method: method, Code: code, Msg: env.Result.Msg})
		}
		return &APIError{Method: method, Code: code, Msg: env.Result.Msg}
	}
	if out != nil && len(env.Result.Data) > 0 && string(env.Result.Data) != "null" {
		if err := json.Unmarshal(env.Result.Data, out); err != nil {
			return &APIError{Method: method, Code: "bad_data", Msg: err.Error()}
		}
	}
	return nil
}

func codeString(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	}
	return ""
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// anyStr reads a JSON value that may be a string or a number.
func anyStr(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case bool:
		return strconv.FormatBool(t)
	}
	return ""
}

// ── Driver ──────────────────────────────────────────────────────────────────

// List returns the cameras bound to (or shared with) the account.
func (c *Imou) List(ctx context.Context) ([]Camera, error) {
	var list struct {
		DeviceList []struct {
			DeviceID string `json:"deviceId"`
		} `json:"deviceList"`
	}
	if err := c.call(ctx, "deviceBaseList", map[string]any{
		"bindId":     -1,
		"limit":      50,
		"type":       "bindAndShare",
		"needApInfo": true,
	}, &list); err != nil {
		return nil, err
	}
	if len(list.DeviceList) == 0 {
		return []Camera{}, nil
	}

	req := make([]map[string]any, 0, len(list.DeviceList))
	for _, d := range list.DeviceList {
		req = append(req, map[string]any{"deviceId": d.DeviceID, "channelList": "0"})
	}
	var details struct {
		DeviceList []struct {
			DeviceID    string `json:"deviceId"`
			Name        string `json:"name"`
			DeviceModel string `json:"deviceModel"`
			Ability     string `json:"ability"`
		} `json:"deviceList"`
	}
	if err := c.call(ctx, "deviceBaseDetailList", map[string]any{"deviceList": req}, &details); err != nil {
		return nil, err
	}

	out := make([]Camera, 0, len(details.DeviceList))
	for _, d := range details.DeviceList {
		caps := capsFromAbility(d.Ability)
		cam := Camera{
			ID:          d.DeviceID,
			Name:        d.Name,
			Model:       d.DeviceModel,
			HumanDetect: caps.human,
			PTZ:         caps.ptz,
			Zoom:        caps.zoom,
			Switches:    caps.switches,
		}
		if cam.Name == "" {
			cam.Name = d.DeviceID
		}
		online, err := c.online(ctx, d.DeviceID)
		if err != nil {
			if errors.Is(err, ErrProviderLimit) || errors.Is(err, ErrConfig) {
				return nil, err
			}
			// One camera failing to report must not hide the others.
			online = false
		}
		cam.Online = online
		out = append(out, cam)
	}
	return out, nil
}

func hasAbility(csv string, names ...string) bool {
	for _, a := range strings.Split(csv, ",") {
		a = strings.TrimSpace(a)
		for _, n := range names {
			if strings.EqualFold(a, n) {
				return true
			}
		}
	}
	return false
}

type capabilities struct {
	ptz, zoom, human bool
	switches         []string
}

// capsFromAbility reads Imou's comma-separated `ability` string. The names are
// the ones the open-source client lists (PTZ/PT/PT1/PT2, ZoomFocus,
// CloseCamera, MotionDetect/AlarmMD, HeaderDetect/AiHuman/AiHumanCar,
// WhiteLight/SearchLight, Linkagewhitelight).
func capsFromAbility(csv string) capabilities {
	c := capabilities{switches: []string{}}
	c.ptz = hasAbility(csv, "PTZ", "PT", "PT1", "PT2")
	c.zoom = hasAbility(csv, "ZoomFocus")
	c.human = hasAbility(csv, "HeaderDetect", "AiHuman", "AiHumanCar")
	if hasAbility(csv, "CloseCamera") {
		c.switches = append(c.switches, string(SwitchPrivacy))
	}
	if hasAbility(csv, "MotionDetect", "AlarmMD") {
		c.switches = append(c.switches, string(SwitchMotion))
	}
	if c.human {
		c.switches = append(c.switches, string(SwitchHuman))
	}
	if hasAbility(csv, "WhiteLight", "SearchLight") {
		c.switches = append(c.switches, string(SwitchLight))
	}
	if hasAbility(csv, "Linkagewhitelight") {
		c.switches = append(c.switches, string(SwitchLightAuto))
	}
	return c
}

// ptzOperation is Imou's numeric code for an action.
var ptzOperation = map[PTZAction]int{
	PTZUp: 0, PTZDown: 1, PTZLeft: 2, PTZRight: 3,
	PTZUpLeft: 4, PTZDownLeft: 5, PTZUpRight: 6, PTZDownRight: 7,
	PTZZoomIn: 8, PTZZoomOut: 9, PTZStop: 10,
}

// switchType is the `enableType` Imou uses for each setting.
var switchType = map[SwitchKey]string{
	SwitchPrivacy: "closeCamera",
	SwitchMotion:  "motionDetect",
	SwitchHuman:   "headerDetect",
	// The camera's own light, and "light up when something moves".
	SwitchLight:     "whiteLight",
	SwitchLightAuto: "linkageWhiteLight",
}

// PTZ moves the camera head (controlMovePTZ). Imou takes the operation and
// the duration in milliseconds, both as strings.
func (c *Imou) PTZ(ctx context.Context, id string, a PTZAction, d time.Duration) error {
	op, ok := ptzOperation[a]
	if !ok {
		return ErrBadInput
	}
	return c.call(ctx, "controlMovePTZ", map[string]any{
		"deviceId":  id,
		"channelId": "0",
		"operation": strconv.Itoa(op),
		"duration":  strconv.FormatInt(d.Milliseconds(), 10),
	}, nil)
}

// Switch reads a setting (getDeviceCameraStatus -> status "on"/"off").
func (c *Imou) Switch(ctx context.Context, id string, k SwitchKey) (bool, error) {
	t, ok := switchType[k]
	if !ok {
		return false, ErrBadInput
	}
	var d struct {
		Status string `json:"status"`
	}
	if err := c.call(ctx, "getDeviceCameraStatus", map[string]any{
		"deviceId":   id,
		"channelId":  "0",
		"enableType": t,
	}, &d); err != nil {
		return false, err
	}
	return d.Status == "on", nil
}

// SetSwitch changes a setting (setDeviceCameraStatus with a boolean enable).
func (c *Imou) SetSwitch(ctx context.Context, id string, k SwitchKey, on bool) error {
	t, ok := switchType[k]
	if !ok {
		return ErrBadInput
	}
	return c.call(ctx, "setDeviceCameraStatus", map[string]any{
		"deviceId":   id,
		"channelId":  "0",
		"enableType": t,
		"enable":     on,
	}, nil)
}

// online asks whether the camera is reachable. Imou reports "onLine" as "1"
// when it is, "0" when not (others, like 3, mean upgrading/sleeping).
func (c *Imou) online(ctx context.Context, id string) (bool, error) {
	var d struct {
		OnLine any `json:"onLine"`
	}
	if err := c.call(ctx, "deviceOnline", map[string]any{"deviceId": id}, &d); err != nil {
		return false, err
	}
	return anyStr(d.OnLine) == "1", nil
}

// Live returns the HLS address for a camera, opening a stream when none is up.
func (c *Imou) Live(ctx context.Context, id string, q Quality) (Live, error) {
	want := "0"
	if q == QualitySD {
		want = "1"
	}

	if u, err := c.existingStream(ctx, id, want); err != nil {
		return Live{}, err
	} else if u != "" {
		return Live{URL: u, Protocol: "hls", Quality: q}, nil
	}

	// None usable yet: open one. "already exists" just means a race with
	// another viewer, so carry on and read it back.
	err := c.call(ctx, "bindDeviceLive", map[string]any{
		"deviceId":  id,
		"channelId": "0",
		"streamId":  mustAtoi(want),
	}, nil)
	var ae *APIError
	if err != nil && !(errors.As(err, &ae) && ae.Code == codeLiveExists) {
		return Live{}, err
	}

	u, err := c.existingStream(ctx, id, want)
	if err != nil {
		return Live{}, err
	}
	if u == "" {
		return Live{}, &APIError{Method: "getLiveStreamInfo", Code: "no_stream", Msg: "no HLS stream after bindDeviceLive"}
	}
	return Live{URL: u, Protocol: "hls", Quality: q}, nil
}

func mustAtoi(s string) int {
	n, _ := strconv.Atoi(s)
	return n
}

// existingStream returns the usable HLS URL of the wanted profile, or "".
func (c *Imou) existingStream(ctx context.Context, id, want string) (string, error) {
	var d struct {
		Streams []struct {
			StreamID any    `json:"streamId"`
			Status   any    `json:"status"`
			HLS      string `json:"hls"`
		} `json:"streams"`
	}
	err := c.call(ctx, "getLiveStreamInfo", map[string]any{"deviceId": id, "channelId": "0"}, &d)
	var ae *APIError
	if err != nil {
		if errors.As(err, &ae) && ae.Code == codeLiveNone {
			return "", nil
		}
		return "", err
	}
	for _, s := range d.Streams {
		if anyStr(s.StreamID) != want || anyStr(s.Status) != "1" {
			continue
		}
		if strings.HasPrefix(s.HLS, "https://") {
			return s.HLS, nil
		}
	}
	return "", nil
}

// maxSnapshotBytes caps what we will read from a snapshot URL.
const maxSnapshotBytes = 4 << 20

// Snapshot asks the camera for a still picture and downloads it.
func (c *Imou) Snapshot(ctx context.Context, id string) (Image, error) {
	var d struct {
		URL string `json:"url"`
	}
	if err := c.call(ctx, "setDeviceSnapEnhanced", map[string]any{"deviceId": id, "channelId": "0"}, &d); err != nil {
		return Image{}, err
	}
	u, err := url.Parse(d.URL)
	if err != nil || u.Scheme != "https" || u.Host == "" {
		return Image{}, &APIError{Method: "setDeviceSnapEnhanced", Code: "bad_url", Msg: "no https image url"}
	}

	// The picture is not ready the instant the call returns.
	select {
	case <-time.After(c.cfg.SnapshotWait):
	case <-ctx.Done():
		return Image{}, ctx.Err()
	}

	// Fetched without credentials: the URL carries its own authorisation.
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, d.URL, nil)
	if err != nil {
		return Image{}, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return Image{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return Image{}, &APIError{Method: "snapshot", Code: "http_" + strconv.Itoa(resp.StatusCode)}
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxSnapshotBytes))
	if err != nil {
		return Image{}, err
	}
	ct := resp.Header.Get("Content-Type")
	if ct == "" || !strings.HasPrefix(ct, "image/") {
		ct = "image/jpeg"
	}
	return Image{Data: data, ContentType: ct}, nil
}

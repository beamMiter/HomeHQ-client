package cameras

import (
	"bytes"
	"context"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"image/png"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
)

// ── a fake Imou cloud ───────────────────────────────────────────────────────

type fakeImou struct {
	t      *testing.T
	secret string

	mu    sync.Mutex
	calls []string // method names in order
	// per-method behaviour; return the "result" object (code/msg/data)
	handlers map[string]func(params map[string]any) (code string, data any)
	// number of upcoming calls that should answer TK1002
	expireNext int
	token      int
	pic        []byte
}

func newFakeImou(t *testing.T) (*fakeImou, *Imou, *httptest.Server) {
	f := &fakeImou{t: t, secret: "s3cret", handlers: map[string]func(map[string]any) (string, any){}}
	srv := httptest.NewTLSServer(http.HandlerFunc(f.serve))
	t.Cleanup(srv.Close)
	c := NewImou(ImouConfig{AppID: "app1", AppSecret: f.secret, BaseURL: srv.URL + "/openapi", SnapshotWait: time.Millisecond})
	c.http = srv.Client()
	return f, c, srv
}

func (f *fakeImou) count(method string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for _, m := range f.calls {
		if m == method {
			n++
		}
	}
	return n
}

func (f *fakeImou) serve(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/pic.jpg" {
		// The snapshot is fetched from a separate address, with no credentials.
		if r.Header.Get("Authorization") != "" {
			f.t.Error("the picture must be fetched without our credentials")
		}
		w.Header().Set("Content-Type", "image/jpeg")
		_, _ = w.Write(f.pic)
		return
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	method := strings.TrimPrefix(r.URL.Path, "/openapi/")
	f.calls = append(f.calls, method)

	var body struct {
		System struct {
			Ver, Sign, AppID string
			Time             int64
			Nonce            string
		} `json:"system"`
		Params map[string]any `json:"params"`
		ID     string         `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		f.t.Errorf("bad request body: %v", err)
	}

	// The signature is how Imou authenticates the app: check it for real.
	sum := md5.Sum([]byte(fmt.Sprintf("time:%d,nonce:%s,appSecret:%s", body.System.Time, body.System.Nonce, f.secret)))
	if body.System.Sign != hex.EncodeToString(sum[:]) || body.System.AppID != "app1" || body.System.Ver != "1.0" {
		f.reply(w, "OP1008", nil)
		return
	}

	if method == "accessToken" {
		f.token++
		f.reply(w, "0", map[string]any{"accessToken": fmt.Sprintf("tok-%d", f.token), "expireTime": 259200})
		return
	}
	if body.Params["token"] != fmt.Sprintf("tok-%d", f.token) || f.expireNext > 0 {
		if f.expireNext > 0 {
			f.expireNext--
		}
		f.reply(w, "TK1002", nil)
		return
	}
	h, ok := f.handlers[method]
	if !ok {
		f.reply(w, "UNKNOWN", nil)
		return
	}
	code, data := h(body.Params)
	f.reply(w, code, data)
}

func (f *fakeImou) reply(w http.ResponseWriter, code string, data any) {
	res := map[string]any{"code": code, "msg": "m"}
	if data != nil {
		res["data"] = data
	}
	_ = json.NewEncoder(w).Encode(map[string]any{"result": res, "id": "1"})
}

// ── Imou driver ─────────────────────────────────────────────────────────────

func TestImouListsCamerasWithDetailsAndOnlineState(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["deviceBaseList"] = func(p map[string]any) (string, any) {
		return "0", map[string]any{"count": 2, "deviceList": []map[string]any{{"deviceId": "AAAA1111"}, {"deviceId": "BBBB2222"}}}
	}
	f.handlers["deviceBaseDetailList"] = func(p map[string]any) (string, any) {
		return "0", map[string]any{"deviceList": []map[string]any{
			{"deviceId": "AAAA1111", "name": "Front door", "deviceModel": "IPC-A22", "ability": "WLM,HeaderDetect,MotionDetect"},
			{"deviceId": "BBBB2222", "name": "", "deviceModel": "IPC-C22", "ability": "WLM"},
		}}
	}
	f.handlers["deviceOnline"] = func(p map[string]any) (string, any) {
		if p["deviceId"] == "AAAA1111" {
			return "0", map[string]any{"onLine": "1"}
		}
		return "0", map[string]any{"onLine": "0"}
	}

	got, err := c.List(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 cameras, got %d", len(got))
	}
	if got[0].Name != "Front door" || !got[0].Online || !got[0].HumanDetect || got[0].Model != "IPC-A22" {
		t.Errorf("camera 0 wrong: %+v", got[0])
	}
	if got[1].Name != "BBBB2222" || got[1].Online || got[1].HumanDetect {
		t.Errorf("camera 1 should fall back to its id and be offline: %+v", got[1])
	}
}

func TestImouKeepsOneTokenAcrossCalls(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["deviceOnline"] = func(map[string]any) (string, any) { return "0", map[string]any{"onLine": "1"} }
	for i := 0; i < 3; i++ {
		if _, err := c.online(context.Background(), "AAAA1111"); err != nil {
			t.Fatal(err)
		}
	}
	if n := f.count("accessToken"); n != 1 {
		t.Errorf("token should be fetched once, fetched %d times", n)
	}
}

func TestImouRefreshesAnExpiredTokenOnce(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["deviceOnline"] = func(map[string]any) (string, any) { return "0", map[string]any{"onLine": "1"} }
	if _, err := c.online(context.Background(), "AAAA1111"); err != nil {
		t.Fatal(err)
	}

	f.mu.Lock()
	f.expireNext = 1
	f.mu.Unlock()
	// The first attempt answers TK1002; the client must fetch a new token and retry.
	on, err := c.online(context.Background(), "AAAA1111")
	if err != nil || !on {
		t.Fatalf("expected the retry to succeed, got on=%v err=%v", on, err)
	}
	if n := f.count("accessToken"); n != 2 {
		t.Errorf("want a second token fetch, got %d fetches", n)
	}
}

func TestImouDoesNotRetryExpiredTokenForever(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["deviceOnline"] = func(map[string]any) (string, any) { return "0", map[string]any{"onLine": "1"} }
	f.mu.Lock()
	f.expireNext = 100
	f.mu.Unlock()
	if _, err := c.online(context.Background(), "AAAA1111"); err == nil {
		t.Fatal("want an error when the token is always rejected")
	}
	if n := f.count("deviceOnline"); n != 2 {
		t.Errorf("want exactly one retry (2 calls), got %d", n)
	}
}

func TestImouLiveUsesExistingStream(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["getLiveStreamInfo"] = func(map[string]any) (string, any) {
		return "0", map[string]any{"streams": []map[string]any{
			{"streamId": 0, "status": "1", "hls": "https://cdn.example/hd.m3u8", "liveToken": "t0"},
			{"streamId": 1, "status": "1", "hls": "https://cdn.example/sd.m3u8", "liveToken": "t1"},
		}}
	}
	hd, err := c.Live(context.Background(), "AAAA1111", QualityHD)
	if err != nil || hd.URL != "https://cdn.example/hd.m3u8" || hd.Protocol != "hls" || hd.Quality != QualityHD {
		t.Fatalf("hd: %+v err=%v", hd, err)
	}
	sd, err := c.Live(context.Background(), "AAAA1111", QualitySD)
	if err != nil || sd.URL != "https://cdn.example/sd.m3u8" {
		t.Fatalf("sd: %+v err=%v", sd, err)
	}
	if n := f.count("bindDeviceLive"); n != 0 {
		t.Errorf("an existing stream must not be re-opened, bind called %d times", n)
	}
}

func TestImouLiveOpensAStreamWhenNoneExists(t *testing.T) {
	f, c, _ := newFakeImou(t)
	bound := false
	f.handlers["getLiveStreamInfo"] = func(map[string]any) (string, any) {
		if !bound {
			return "LV1002", nil // nothing live yet
		}
		return "0", map[string]any{"streams": []map[string]any{
			{"streamId": "0", "status": "1", "hls": "https://cdn.example/new.m3u8", "liveToken": "t"},
		}}
	}
	f.handlers["bindDeviceLive"] = func(p map[string]any) (string, any) {
		if p["streamId"] != float64(0) || p["deviceId"] != "AAAA1111" || p["channelId"] != "0" {
			t.Errorf("unexpected bind params: %v", p)
		}
		bound = true
		return "0", map[string]any{"streams": []map[string]any{{"hls": "https://cdn.example/new.m3u8", "liveToken": "t"}}}
	}
	l, err := c.Live(context.Background(), "AAAA1111", QualityHD)
	if err != nil || l.URL != "https://cdn.example/new.m3u8" {
		t.Fatalf("got %+v err=%v", l, err)
	}
}

func TestImouLiveToleratesAlreadyExists(t *testing.T) {
	f, c, _ := newFakeImou(t)
	calls := 0
	f.handlers["getLiveStreamInfo"] = func(map[string]any) (string, any) {
		calls++
		if calls == 1 {
			return "0", map[string]any{"streams": []map[string]any{}} // none usable
		}
		return "0", map[string]any{"streams": []map[string]any{
			{"streamId": 0, "status": 1, "hls": "https://cdn.example/x.m3u8"},
		}}
	}
	f.handlers["bindDeviceLive"] = func(map[string]any) (string, any) { return "LV1001", nil }
	l, err := c.Live(context.Background(), "AAAA1111", QualityHD)
	if err != nil || l.URL == "" {
		t.Fatalf("LV1001 should be ignored: %+v err=%v", l, err)
	}
}

func TestImouLiveIgnoresPlainHTTPStreams(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["getLiveStreamInfo"] = func(map[string]any) (string, any) {
		return "0", map[string]any{"streams": []map[string]any{
			{"streamId": 0, "status": "1", "hls": "http://insecure.example/a.m3u8"},
		}}
	}
	f.handlers["bindDeviceLive"] = func(map[string]any) (string, any) { return "0", nil }
	if _, err := c.Live(context.Background(), "AAAA1111", QualityHD); err == nil {
		t.Fatal("an http:// stream address must not be handed to the app")
	}
}

func TestImouSnapshotDownloadsTheImage(t *testing.T) {
	f, c, srv := newFakeImou(t)
	f.pic = []byte("\xff\xd8\xff fake jpeg")
	f.handlers["setDeviceSnapEnhanced"] = func(p map[string]any) (string, any) {
		if p["deviceId"] != "AAAA1111" || p["channelId"] != "0" {
			t.Errorf("unexpected snapshot params: %v", p)
		}
		return "0", map[string]any{"url": srv.URL + "/pic.jpg"}
	}
	got, err := c.Snapshot(context.Background(), "AAAA1111")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got.Data, f.pic) || got.ContentType != "image/jpeg" {
		t.Errorf("unexpected image: %q %q", got.Data, got.ContentType)
	}
}

func TestImouSnapshotRejectsNonHTTPSURL(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["setDeviceSnapEnhanced"] = func(map[string]any) (string, any) {
		return "0", map[string]any{"url": "http://insecure.example/x.jpg"}
	}
	if _, err := c.Snapshot(context.Background(), "AAAA1111"); err == nil {
		t.Fatal("want an error for a non-https image url")
	}
}

func TestImouMapsCredentialErrors(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.secret = "something-else" // the client signs with the real one; server now disagrees
	_, err := c.List(context.Background())
	if !errors.Is(err, ErrConfig) {
		t.Fatalf("want ErrConfig, got %v", err)
	}
}

func TestImouOwnCallLimitIsReportedAsSuch(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["deviceOnline"] = func(map[string]any) (string, any) {
		return "OP1013", nil // "Call interface times exceed limit"
	}
	_, err := c.online(context.Background(), "AAAA1111")
	if !errors.Is(err, ErrProviderLimit) {
		t.Fatalf("want ErrProviderLimit, got %v", err)
	}
}

func TestThereIsNoCallCountingOnOurSide(t *testing.T) {
	// Hundreds of calls in a row: nothing of ours refuses any of them.
	f, c, _ := newFakeImou(t)
	f.handlers["deviceOnline"] = func(map[string]any) (string, any) { return "0", map[string]any{"onLine": "1"} }
	for i := 0; i < 300; i++ {
		if _, err := c.online(context.Background(), "AAAA1111"); err != nil {
			t.Fatalf("call %d refused: %v", i, err)
		}
	}
}

func TestImouWithoutCredentialsIsDisabled(t *testing.T) {
	c := NewImou(ImouConfig{})
	if _, err := c.List(context.Background()); !errors.Is(err, ErrDisabled) {
		t.Fatalf("want ErrDisabled, got %v", err)
	}
}

func TestImouRegionPicksHost(t *testing.T) {
	if c := NewImou(ImouConfig{Region: "sg"}); !strings.Contains(c.base, "openapi-sg") {
		t.Errorf("sg base = %s", c.base)
	}
	if c := NewImou(ImouConfig{}); c.base != DefaultImouBaseURL {
		t.Errorf("default base = %s", c.base)
	}
	if c := NewImou(ImouConfig{BaseURL: "https://x.example/openapi/", Region: "sg"}); c.base != "https://x.example/openapi" {
		t.Errorf("explicit base should win and lose its slash: %s", c.base)
	}
}

func TestTokenLifetimeIsDefensive(t *testing.T) {
	now := time.Unix(1_700_000_000, 0)
	if d := tokenLifetime(float64(259200), now); d != maxTokenAge {
		t.Errorf("3 days should be capped to %v, got %v", maxTokenAge, d)
	}
	if d := tokenLifetime(float64(5), now); d != time.Minute {
		t.Errorf("tiny lifetimes floor at a minute, got %v", d)
	}
	abs := float64(now.Add(2 * time.Hour).Unix())
	if d := tokenLifetime(abs, now); d != 2*time.Hour {
		t.Errorf("absolute timestamp should become a duration, got %v", d)
	}
	if d := tokenLifetime("3600", now); d != time.Hour {
		t.Errorf("string seconds, got %v", d)
	}
	if d := tokenLifetime(nil, now); d != maxTokenAge {
		t.Errorf("unknown shape falls back to the cap, got %v", d)
	}
}

// ── fake driver ─────────────────────────────────────────────────────────────

func TestFakeDriver(t *testing.T) {
	f := NewFake("")
	ctx := context.Background()
	list, _ := f.List(ctx)
	if len(list) != 3 {
		t.Fatalf("want 3 demo cameras, got %d", len(list))
	}
	if _, err := f.Live(ctx, "FAKE-BACK-YARD", QualityHD); !errors.Is(err, ErrOffline) {
		t.Errorf("offline camera: %v", err)
	}
	if _, err := f.Live(ctx, "NOPE", QualityHD); !errors.Is(err, ErrNotFound) {
		t.Errorf("unknown camera: %v", err)
	}
	l, err := f.Live(ctx, "FAKE-FRONT-DOOR", QualitySD)
	if err != nil || l.URL != DefaultFakeStreamURL || l.Quality != QualitySD {
		t.Errorf("live: %+v %v", l, err)
	}
	img, err := f.Snapshot(ctx, "FAKE-PARCEL-SPOT")
	if err != nil || img.ContentType != "image/png" {
		t.Fatalf("snapshot: %v", err)
	}
	if _, err := png.Decode(bytes.NewReader(img.Data)); err != nil {
		t.Errorf("snapshot is not a valid PNG: %v", err)
	}
}

// ── service ─────────────────────────────────────────────────────────────────

// countingDriver wraps Fake and counts calls.
type countingDriver struct {
	*Fake
	mu                          sync.Mutex
	lists, lives, snapshotCalls int
}

func (d *countingDriver) List(ctx context.Context) ([]Camera, error) {
	d.mu.Lock()
	d.lists++
	d.mu.Unlock()
	return d.Fake.List(ctx)
}
func (d *countingDriver) Live(ctx context.Context, id string, q Quality) (Live, error) {
	d.mu.Lock()
	d.lives++
	d.mu.Unlock()
	return d.Fake.Live(ctx, id, q)
}
func (d *countingDriver) Snapshot(ctx context.Context, id string) (Image, error) {
	d.mu.Lock()
	d.snapshotCalls++
	d.mu.Unlock()
	return d.Fake.Snapshot(ctx, id)
}

func TestServiceCachesListSnapshotAndLive(t *testing.T) {
	d := &countingDriver{Fake: NewFake("")}
	s := NewService(d)
	now := time.Unix(1_700_000_000, 0)
	s.now = func() time.Time { return now }
	ctx := context.Background()

	for i := 0; i < 3; i++ {
		if _, err := s.List(ctx); err != nil {
			t.Fatal(err)
		}
		if _, err := s.Snapshot(ctx, "FAKE-FRONT-DOOR"); err != nil {
			t.Fatal(err)
		}
		if _, err := s.Live(ctx, "FAKE-FRONT-DOOR", QualityHD); err != nil {
			t.Fatal(err)
		}
	}
	if d.lists != 1 || d.snapshotCalls != 1 || d.lives != 1 {
		t.Errorf("want one driver call each, got list=%d snap=%d live=%d", d.lists, d.snapshotCalls, d.lives)
	}

	now = now.Add(2 * time.Minute) // past every TTL
	_, _ = s.List(ctx)
	_, _ = s.Snapshot(ctx, "FAKE-FRONT-DOOR")
	if d.lists != 2 || d.snapshotCalls != 2 {
		t.Errorf("caches should expire: list=%d snap=%d", d.lists, d.snapshotCalls)
	}
}

func TestServiceKnownOfflineCameraCostsNoVendorCall(t *testing.T) {
	d := &countingDriver{Fake: NewFake("")}
	s := NewService(d)
	ctx := context.Background()
	if _, err := s.List(ctx); err != nil {
		t.Fatal(err)
	}
	before := d.lives
	if _, err := s.Live(ctx, "FAKE-BACK-YARD", QualityHD); !errors.Is(err, ErrOffline) {
		t.Fatalf("want ErrOffline, got %v", err)
	}
	if _, err := s.Snapshot(ctx, "FAKE-BACK-YARD"); !errors.Is(err, ErrOffline) {
		t.Fatalf("want ErrOffline, got %v", err)
	}
	if d.lives != before || d.snapshotCalls != 0 {
		t.Errorf("an offline camera must not reach the driver (lives %d->%d, snaps %d)", before, d.lives, d.snapshotCalls)
	}
}

func TestServiceRejectsBadIDsAndIsOffWithoutDriver(t *testing.T) {
	s := NewService(NewFake(""))
	for _, id := range []string{"", "a", "../etc/passwd", "has space", strings.Repeat("x", 100)} {
		if _, err := s.Live(context.Background(), id, QualityHD); !errors.Is(err, ErrBadInput) {
			t.Errorf("id %q: want ErrBadInput, got %v", id, err)
		}
	}
	off := NewService(nil)
	if off.Enabled() {
		t.Error("nil driver must be disabled")
	}
	if _, err := off.List(context.Background()); !errors.Is(err, ErrDisabled) {
		t.Errorf("want ErrDisabled, got %v", err)
	}
	if st := off.Status(); st.Enabled {
		t.Errorf("status = %+v", st)
	}
}

func TestParseQuality(t *testing.T) {
	for in, want := range map[string]Quality{"": QualityHD, "hd": QualityHD, "sd": QualitySD} {
		if q, ok := ParseQuality(in); !ok || q != want {
			t.Errorf("ParseQuality(%q) = %v,%v", in, q, ok)
		}
	}
	if _, ok := ParseQuality("4k"); ok {
		t.Error("4k should be rejected")
	}
}

// ── HTTP ────────────────────────────────────────────────────────────────────

func newTestHandler(t *testing.T, drv Driver) (*Handler, http.Handler) {
	t.Helper()
	h := NewHandler(NewService(drv))
	r := chi.NewRouter()
	r.Route("/cameras", h.RegisterRoutes)
	return h, r
}

func get(r http.Handler, path string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestHTTPDisabledAnswers503ButStatusAlwaysWorks(t *testing.T) {
	_, r := newTestHandler(t, nil)
	if rec := get(r, "/cameras/status"); rec.Code != 200 || !strings.Contains(rec.Body.String(), `"enabled":false`) {
		t.Errorf("status: %d %s", rec.Code, rec.Body)
	}
	rec := get(r, "/cameras/")
	if rec.Code != http.StatusServiceUnavailable || !strings.Contains(rec.Body.String(), "cameras_disabled") {
		t.Errorf("list: %d %s", rec.Code, rec.Body)
	}
}

func TestHTTPListLiveAndSnapshot(t *testing.T) {
	_, r := newTestHandler(t, NewFake(""))

	rec := get(r, "/cameras/")
	if rec.Code != 200 {
		t.Fatalf("list: %d %s", rec.Code, rec.Body)
	}
	var list struct {
		Items []Camera `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil || len(list.Items) != 3 {
		t.Fatalf("list body: %v %s", err, rec.Body)
	}

	rec = get(r, "/cameras/FAKE-FRONT-DOOR/live?quality=sd")
	if rec.Code != 200 || rec.Header().Get("Cache-Control") != "no-store" {
		t.Errorf("live: %d cache=%q", rec.Code, rec.Header().Get("Cache-Control"))
	}
	if !strings.Contains(rec.Body.String(), `"quality":"sd"`) || !strings.Contains(rec.Body.String(), `"protocol":"hls"`) {
		t.Errorf("live body: %s", rec.Body)
	}

	rec = get(r, "/cameras/FAKE-FRONT-DOOR/snapshot")
	if rec.Code != 200 || rec.Header().Get("Content-Type") != "image/png" {
		t.Fatalf("snapshot: %d %s", rec.Code, rec.Header().Get("Content-Type"))
	}
	if !strings.HasPrefix(rec.Header().Get("Cache-Control"), "private") {
		t.Errorf("a picture of the home must be private-cached: %q", rec.Header().Get("Cache-Control"))
	}
	if _, err := png.Decode(rec.Body); err != nil {
		t.Errorf("snapshot body: %v", err)
	}
}

func TestHTTPErrorsAreMapped(t *testing.T) {
	_, r := newTestHandler(t, NewFake(""))
	_ = get(r, "/cameras/") // learn who is offline

	cases := []struct {
		path string
		code int
		body string
	}{
		{"/cameras/FAKE-BACK-YARD/live", http.StatusConflict, "camera_offline"},
		{"/cameras/NOT-A-CAMERA/live", http.StatusNotFound, "camera_not_found"},
		{"/cameras/FAKE-FRONT-DOOR/live?quality=4k", http.StatusBadRequest, "invalid quality"},
		{"/cameras/a/live", http.StatusBadRequest, "invalid input"},
	}
	for _, c := range cases {
		rec := get(r, c.path)
		if rec.Code != c.code || !strings.Contains(rec.Body.String(), c.body) {
			t.Errorf("%s: got %d %s, want %d %s", c.path, rec.Code, rec.Body, c.code, c.body)
		}
	}
}

func TestHTTPNoRateLimitForTheHousehold(t *testing.T) {
	_, r := newTestHandler(t, NewFake(""))
	for i := 0; i < 200; i++ {
		if rec := get(r, "/cameras/"); rec.Code != 200 {
			t.Fatalf("request %d refused: %d %s", i, rec.Code, rec.Body)
		}
	}
}

func TestHTTPProviderLimitAnswers429(t *testing.T) {
	// Imou refusing because of its own allowance is passed on as such.
	f, c, _ := newFakeImou(t)
	f.handlers["deviceBaseList"] = func(map[string]any) (string, any) { return "OP1013", nil }
	h := NewHandler(NewService(c))
	r := chi.NewRouter()
	r.Route("/cameras", h.RegisterRoutes)
	rec := get(r, "/cameras/")
	if rec.Code != http.StatusTooManyRequests || !strings.Contains(rec.Body.String(), "provider_limit") {
		t.Errorf("got %d %s", rec.Code, rec.Body)
	}
}

func TestStatusHasNoQuotaFields(t *testing.T) {
	_, r := newTestHandler(t, NewFake(""))
	rec := get(r, "/cameras/status")
	if rec.Code != 200 {
		t.Fatalf("status: %d", rec.Code)
	}
	if body := rec.Body.String(); strings.Contains(body, "daily") || strings.Contains(body, "limit") {
		t.Errorf("status should not report a quota: %s", body)
	}
}

// ── capabilities, PTZ and switches ──────────────────────────────────────────

func TestCapsFromAbility(t *testing.T) {
	c := capsFromAbility("WLM,PT,ZoomFocus,CloseCamera,MotionDetect,HeaderDetect,WhiteLight,Linkagewhitelight")
	if !c.ptz || !c.zoom || !c.human {
		t.Errorf("caps = %+v", c)
	}
	if got := strings.Join(c.switches, ","); got != "privacy,motion,human,light,light_auto" {
		t.Errorf("switches = %q", got)
	}
	// a camera with a light but nothing else
	if got := strings.Join(capsFromAbility("WhiteLight").switches, ","); got != "light" {
		t.Errorf("light only: %q", got)
	}

	none := capsFromAbility("WLM,LocalStorage")
	if none.ptz || none.zoom || none.human || len(none.switches) != 0 {
		t.Errorf("a plain camera has no extras: %+v", none)
	}
	if none.switches == nil {
		t.Error("switches must be an empty list, not null, in the JSON")
	}

	// case-insensitive, tolerant of stray spaces
	if c := capsFromAbility(" ptz , aihuman "); !c.ptz || !c.human {
		t.Errorf("tolerant parse failed: %+v", c)
	}
}

func TestImouListReportsCapabilities(t *testing.T) {
	f, c, _ := newFakeImou(t)
	f.handlers["deviceBaseList"] = func(map[string]any) (string, any) {
		return "0", map[string]any{"deviceList": []map[string]any{{"deviceId": "AAAA1111"}}}
	}
	f.handlers["deviceBaseDetailList"] = func(map[string]any) (string, any) {
		return "0", map[string]any{"deviceList": []map[string]any{
			{"deviceId": "AAAA1111", "name": "Door", "ability": "PT,CloseCamera,AiHuman"},
		}}
	}
	f.handlers["deviceOnline"] = func(map[string]any) (string, any) { return "0", map[string]any{"onLine": "1"} }
	got, err := c.List(context.Background())
	if err != nil || len(got) != 1 {
		t.Fatalf("%v %v", got, err)
	}
	cam := got[0]
	if !cam.PTZ || cam.Zoom || !cam.HumanDetect {
		t.Errorf("caps: %+v", cam)
	}
	if strings.Join(cam.Switches, ",") != "privacy,human" {
		t.Errorf("switches: %v", cam.Switches)
	}
}

func TestImouPTZSendsOperationAndDuration(t *testing.T) {
	f, c, _ := newFakeImou(t)
	var seen []map[string]any
	f.handlers["controlMovePTZ"] = func(p map[string]any) (string, any) {
		seen = append(seen, p)
		return "0", nil
	}
	cases := []struct {
		a  PTZAction
		op string
	}{
		{PTZUp, "0"}, {PTZDown, "1"}, {PTZLeft, "2"}, {PTZRight, "3"},
		{PTZUpLeft, "4"}, {PTZDownLeft, "5"}, {PTZUpRight, "6"}, {PTZDownRight, "7"},
		{PTZZoomIn, "8"}, {PTZZoomOut, "9"}, {PTZStop, "10"},
	}
	for _, tc := range cases {
		if err := c.PTZ(context.Background(), "AAAA1111", tc.a, 750*time.Millisecond); err != nil {
			t.Fatalf("%s: %v", tc.a, err)
		}
	}
	if len(seen) != len(cases) {
		t.Fatalf("want %d requests, got %d", len(cases), len(seen))
	}
	for i, tc := range cases {
		p := seen[i]
		if p["operation"] != tc.op || p["duration"] != "750" || p["deviceId"] != "AAAA1111" || p["channelId"] != "0" {
			t.Errorf("%s: params %v, want operation %s", tc.a, p, tc.op)
		}
	}
	if err := c.PTZ(context.Background(), "AAAA1111", PTZAction("spin"), time.Second); !errors.Is(err, ErrBadInput) {
		t.Errorf("unknown action: %v", err)
	}
}

func TestImouSwitchesReadAndWrite(t *testing.T) {
	f, c, _ := newFakeImou(t)
	state := map[string]bool{"closeCamera": true}
	var wrote []map[string]any
	f.handlers["getDeviceCameraStatus"] = func(p map[string]any) (string, any) {
		s := "off"
		if state[p["enableType"].(string)] {
			s = "on"
		}
		return "0", map[string]any{"status": s, "enableType": p["enableType"]}
	}
	f.handlers["setDeviceCameraStatus"] = func(p map[string]any) (string, any) {
		wrote = append(wrote, p)
		state[p["enableType"].(string)] = p["enable"].(bool)
		return "0", nil
	}

	ctx := context.Background()
	on, err := c.Switch(ctx, "AAAA1111", SwitchPrivacy)
	if err != nil || !on {
		t.Fatalf("privacy should read on: %v %v", on, err)
	}
	on, _ = c.Switch(ctx, "AAAA1111", SwitchMotion)
	if on {
		t.Error("motion should read off")
	}
	if err := c.SetSwitch(ctx, "AAAA1111", SwitchHuman, true); err != nil {
		t.Fatal(err)
	}
	if len(wrote) != 1 || wrote[0]["enableType"] != "headerDetect" || wrote[0]["enable"] != true {
		t.Errorf("write params: %v", wrote)
	}
}

func TestImouLightSwitchesUseTheRightTypes(t *testing.T) {
	f, c, _ := newFakeImou(t)
	var types []string
	f.handlers["setDeviceCameraStatus"] = func(p map[string]any) (string, any) {
		types = append(types, fmt.Sprintf("%v=%v", p["enableType"], p["enable"]))
		return "0", nil
	}
	ctx := context.Background()
	if err := c.SetSwitch(ctx, "AAAA1111", SwitchLight, true); err != nil {
		t.Fatal(err)
	}
	if err := c.SetSwitch(ctx, "AAAA1111", SwitchLightAuto, false); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(types, ","); got != "whiteLight=true,linkageWhiteLight=false" {
		t.Errorf("sent %q", got)
	}
}

func fakeSvc() (*Fake, *Service) {
	d := NewFake("")
	return d, NewService(d)
}

func TestServicePTZClampsDurationAndChecksCapability(t *testing.T) {
	d, s := fakeSvc()
	ctx := context.Background()
	if _, err := s.List(ctx); err != nil { // learn capabilities
		t.Fatal(err)
	}

	for _, tc := range []struct {
		in   time.Duration
		want int64
	}{
		{0, 500},                     // default
		{10 * time.Millisecond, 100}, // floor
		{250 * time.Millisecond, 250},
		{time.Minute, 3000}, // ceiling: a lost "stop" can't swing for a minute
	} {
		if err := s.PTZ(ctx, "FAKE-FRONT-DOOR", PTZLeft, tc.in); err != nil {
			t.Fatal(err)
		}
		moves := d.Moves()
		want := fmt.Sprintf("FAKE-FRONT-DOOR left %d", tc.want)
		if got := moves[len(moves)-1]; got != want {
			t.Errorf("in=%v: got %q want %q", tc.in, got, want)
		}
	}

	// a camera that can't turn is refused without reaching the driver
	before := len(d.Moves())
	if err := s.PTZ(ctx, "FAKE-PARCEL-SPOT", PTZLeft, 0); !errors.Is(err, ErrUnsupported) {
		t.Errorf("want ErrUnsupported, got %v", err)
	}
	if len(d.Moves()) != before {
		t.Error("an unsupported move must not be sent")
	}
	// offline wins over everything
	if err := s.PTZ(ctx, "FAKE-BACK-YARD", PTZLeft, 0); !errors.Is(err, ErrOffline) {
		t.Errorf("want ErrOffline, got %v", err)
	}
}

func TestServiceSwitchesOnlyOfferWhatTheCameraHas(t *testing.T) {
	_, s := fakeSvc()
	ctx := context.Background()

	got, err := s.SwitchStates(ctx, "FAKE-PARCEL-SPOT") // loads the list itself
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 3 || got["privacy"] || !got["motion"] || !got["human"] || got["light"] {
		t.Errorf("parcel camera states: %v", got)
	}
	if _, has := got["privacy"]; has {
		t.Error("a camera without privacy mode must not report it")
	}

	if err := s.SetSwitch(ctx, "FAKE-PARCEL-SPOT", SwitchPrivacy, true); !errors.Is(err, ErrUnsupported) {
		t.Errorf("want ErrUnsupported, got %v", err)
	}
	if err := s.SetSwitch(ctx, "FAKE-FRONT-DOOR", SwitchPrivacy, true); err != nil {
		t.Fatal(err)
	}
	s.Refresh()
	states, _ := s.SwitchStates(ctx, "FAKE-FRONT-DOOR")
	if !states["privacy"] {
		t.Errorf("privacy should now read on: %v", states)
	}
}

func post(r http.Handler, path, body string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, path, strings.NewReader(body)))
	return rec
}

func put(r http.Handler, path, body string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, httptest.NewRequest(http.MethodPut, path, strings.NewReader(body)))
	return rec
}

func TestHTTPPTZ(t *testing.T) {
	_, r := newTestHandler(t, NewFake(""))
	_ = get(r, "/cameras/")

	if rec := post(r, "/cameras/FAKE-FRONT-DOOR/ptz", `{"action":"up_left","duration_ms":400}`); rec.Code != 200 {
		t.Fatalf("move: %d %s", rec.Code, rec.Body)
	}
	cases := []struct {
		path, body string
		code       int
		want       string
	}{
		{"/cameras/FAKE-FRONT-DOOR/ptz", `{"action":"spin"}`, 400, "invalid action"},
		{"/cameras/FAKE-FRONT-DOOR/ptz", `not json`, 400, "invalid body"},
		{"/cameras/FAKE-PARCEL-SPOT/ptz", `{"action":"left"}`, 422, "not_supported"},
		{"/cameras/FAKE-BACK-YARD/ptz", `{"action":"left"}`, 409, "camera_offline"},
		{"/cameras/NOPE-NOPE/ptz", `{"action":"left"}`, 404, "camera_not_found"},
	}
	for _, c := range cases {
		rec := post(r, c.path, c.body)
		if rec.Code != c.code || !strings.Contains(rec.Body.String(), c.want) {
			t.Errorf("%s %s: got %d %s, want %d %s", c.path, c.body, rec.Code, rec.Body, c.code, c.want)
		}
	}
}

func TestHTTPPTZAndSwitchesAreNotLogged(t *testing.T) {
	// Who turned a camera or flipped a setting is not recorded: it is one
	// household, and nothing needs that trail.
	var buf bytes.Buffer
	old := log.Writer()
	log.SetOutput(&buf)
	t.Cleanup(func() { log.SetOutput(old) })

	_, r := newTestHandler(t, NewFake(""))
	_ = get(r, "/cameras/")
	if rec := post(r, "/cameras/FAKE-FRONT-DOOR/ptz", `{"action":"left"}`); rec.Code != 200 {
		t.Fatalf("ptz: %d", rec.Code)
	}
	if rec := put(r, "/cameras/FAKE-FRONT-DOOR/switches/motion", `{"on":false}`); rec.Code != 200 {
		t.Fatalf("switch: %d", rec.Code)
	}
	if out := buf.String(); strings.Contains(out, "ptz") || strings.Contains(out, "switch") || strings.Contains(out, "user=") {
		t.Errorf("nothing about who did it should be logged, got: %q", out)
	}
}

func TestHTTPHoldingADirectionIsNeverRefused(t *testing.T) {
	_, r := newTestHandler(t, NewFake(""))
	_ = get(r, "/cameras/")
	for i := 0; i < 200; i++ {
		if rec := post(r, "/cameras/FAKE-FRONT-DOOR/ptz", `{"action":"left"}`); rec.Code != 200 {
			t.Fatalf("move %d refused: %d %s", i, rec.Code, rec.Body)
		}
	}
}

func TestHTTPSwitches(t *testing.T) {
	_, r := newTestHandler(t, NewFake(""))

	rec := get(r, "/cameras/FAKE-FRONT-DOOR/switches")
	if rec.Code != 200 {
		t.Fatalf("get: %d %s", rec.Code, rec.Body)
	}
	var got map[string]bool
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil || len(got) != 5 {
		t.Fatalf("states: %v %s", err, rec.Body)
	}
	if got["light"] || got["light_auto"] || got["privacy"] {
		t.Errorf("light, auto-light and privacy start off: %v", got)
	}

	if rec := put(r, "/cameras/FAKE-FRONT-DOOR/switches/motion", `{"on":false}`); rec.Code != 200 {
		t.Fatalf("put: %d %s", rec.Code, rec.Body)
	}
	got = nil
	_ = json.Unmarshal(get(r, "/cameras/FAKE-FRONT-DOOR/switches").Body.Bytes(), &got)
	if got["motion"] {
		t.Errorf("motion should be off now: %v", got)
	}

	for _, c := range []struct {
		path, body string
		code       int
	}{
		{"/cameras/FAKE-FRONT-DOOR/switches/zzz", `{"on":true}`, 400},
		{"/cameras/FAKE-FRONT-DOOR/switches/motion", `{}`, 400},
		{"/cameras/FAKE-PARCEL-SPOT/switches/privacy", `{"on":true}`, 422},
	} {
		if rec := put(r, c.path, c.body); rec.Code != c.code {
			t.Errorf("%s %s: got %d want %d (%s)", c.path, c.body, rec.Code, c.code, rec.Body)
		}
	}
}

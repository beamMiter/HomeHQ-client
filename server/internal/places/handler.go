package places

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

const rateWindow = time.Minute

// contextCanceled is context.Canceled, named for readability in fail().
var contextCanceled = context.Canceled

// placeIDPattern accepts the ids Google issues (letters, digits, '-', '_') and
// nothing that could change the shape of the upstream URL.
var placeIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{10,200}$`)

type Handler struct {
	svc *Service
	lim *limiter
	now func() time.Time
}

func NewHandler(svc *Service) *Handler {
	return &Handler{
		svc: svc,
		lim: newLimiter(svc.Limits().RatePerMin, rateWindow),
		now: time.Now,
	}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/status", h.status)
	r.Get("/nearby", h.nearby)
	r.Get("/starred", h.starred)
	r.Get("/{id}", h.details)
	r.Put("/{id}/star", h.setStar(true))
	r.Delete("/{id}/star", h.setStar(false))
}

// status: GET /places/status. Always answers, and costs no Google call, so the
// app can learn whether Google is available (and how much allowance is left)
// before deciding to search.
func (h *Handler) status(w http.ResponseWriter, r *http.Request) {
	httpx.JSON(w, http.StatusOK, h.svc.Status())
}

// nearby: GET /places/nearby?lat=&lng=&radius=&type=&q=&limit=
func (h *Handler) nearby(w http.ResponseWriter, r *http.Request) {
	if !h.admit(w, r, true) {
		return
	}
	q := r.URL.Query()

	lat, lng, ok := parseLatLng(q.Get("lat"), q.Get("lng"))
	if !ok {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "lat and lng are required"})
		return
	}

	radius := 3000.0
	if s := q.Get("radius"); s != "" {
		v, err := strconv.ParseFloat(s, 64)
		if err != nil || v <= 0 {
			httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid radius"})
			return
		}
		radius = v
	}

	trade := q.Get("type")
	if trade != "" {
		if _, ok := TradeByKey(trade); !ok {
			httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "unknown type"})
			return
		}
	}

	limit := 0
	if s := q.Get("limit"); s != "" {
		if v, err := strconv.Atoi(s); err == nil {
			limit = v
		}
	}

	items, err := h.svc.Nearby(r.Context(), NearbyInput{
		Lat: lat, Lng: lng, RadiusM: radius,
		Trade: trade, Query: cleanQuery(q.Get("q")), Limit: limit,
	})
	if err != nil {
		h.fail(w, r, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"items":  items,
		"source": "google",
	})
}

// starred: GET /places/starred?lat=&lng=
func (h *Handler) starred(w http.ResponseWriter, r *http.Request) {
	// Looking up stars needs Google; with none starred it answers without it.
	if !h.admit(w, r, false) {
		return
	}
	lat, lng, ok := parseLatLng(r.URL.Query().Get("lat"), r.URL.Query().Get("lng"))
	if !ok {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "lat and lng are required"})
		return
	}
	items, skipped, err := h.svc.Starred(r.Context(), lat, lng)
	if err != nil {
		h.fail(w, r, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"items":   items,
		"skipped": skipped,
		"source":  "google",
	})
}

// details: GET /places/{id}
func (h *Handler) details(w http.ResponseWriter, r *http.Request) {
	if !h.admit(w, r, true) {
		return
	}
	id := chi.URLParam(r, "id")
	if !placeIDPattern.MatchString(id) {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid place id"})
		return
	}
	d, err := h.svc.Details(r.Context(), id)
	if err != nil {
		h.fail(w, r, err)
		return
	}
	httpx.JSON(w, http.StatusOK, d)
}

// setStar: PUT|DELETE /places/{id}/star   (PUT body: {"trade": "plumber"})
//
// Only touches our own table, so it works with Google switched off.
func (h *Handler) setStar(on bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		if !placeIDPattern.MatchString(id) {
			httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid place id"})
			return
		}

		var body struct {
			Trade string `json:"trade"`
		}
		if on && r.Body != nil {
			// An empty body is fine; the trade is only a label.
			raw, _ := io.ReadAll(io.LimitReader(r.Body, 1<<10))
			if len(raw) > 0 {
				if err := json.Unmarshal(raw, &body); err != nil {
					httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
					return
				}
			}
		}

		uid, _ := auth.UserIDFrom(r)
		if err := h.svc.SetStar(r.Context(), id, body.Trade, uid, on); err != nil {
			if errors.Is(err, ErrBadInput) {
				httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "unknown type"})
				return
			}
			log.Printf("places: set star failed: %v", err)
			httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": "star_failed"})
			return
		}
		httpx.JSON(w, http.StatusOK, map[string]any{"place_id": id, "starred": on})
	}
}

// admit rejects the request when it needs Google and Google is not configured,
// or when the user is over their per-minute budget. needsGoogle=false lets a
// request through when Google is off (the handler then decides).
func (h *Handler) admit(w http.ResponseWriter, r *http.Request, needsGoogle bool) bool {
	if needsGoogle && !h.svc.Enabled() {
		httpx.JSON(w, http.StatusServiceUnavailable, map[string]string{"error": "google_places_disabled"})
		return false
	}
	key := "anon"
	if uid, ok := auth.UserIDFrom(r); ok {
		key = uid
	}
	if !h.lim.allow(key, h.now()) {
		w.Header().Set("Retry-After", strconv.Itoa(int(rateWindow.Seconds())))
		httpx.JSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate_limited"})
		return false
	}
	return true
}

// fail maps service errors to responses. The upstream detail stays in our logs
// and never reaches the client.
func (h *Handler) fail(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, ErrDisabled):
		httpx.JSON(w, http.StatusServiceUnavailable, map[string]string{"error": "google_places_disabled"})
	case errors.Is(err, ErrBudget):
		httpx.JSON(w, http.StatusTooManyRequests, map[string]string{"error": "daily_limit"})
	case errors.Is(err, ErrQueryRequired):
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "type_or_q_required"})
	case errors.Is(err, ErrBadInput):
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid input"})
	case errors.Is(err, ErrNotFound):
		httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "place_not_found"})
	case errors.Is(err, contextCanceled):
		// The client went away; nothing to send.
	default:
		log.Printf("places: upstream error: %v", err)
		httpx.JSON(w, http.StatusBadGateway, map[string]string{"error": "google_places_unavailable"})
	}
}

func parseLatLng(latS, lngS string) (lat, lng float64, ok bool) {
	lat, err1 := strconv.ParseFloat(latS, 64)
	lng, err2 := strconv.ParseFloat(lngS, 64)
	if err1 != nil || err2 != nil || lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		return 0, 0, false
	}
	return lat, lng, true
}

package cameras

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/status", h.status)
	r.Get("/", h.list)
	r.Get("/{id}/live", h.live)
	r.Get("/{id}/snapshot", h.snapshot)
	r.Post("/{id}/ptz", h.ptz)
	r.Get("/{id}/switches", h.switches)
	r.Put("/{id}/switches/{key}", h.setSwitch)
}

// ptz: POST /cameras/{id}/ptz   {"action":"left","duration_ms":600}
func (h *Handler) ptz(w http.ResponseWriter, r *http.Request) {
	if !h.admit(w, r) {
		return
	}
	var body struct {
		Action     string `json:"action"`
		DurationMS int    `json:"duration_ms"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<10)).Decode(&body); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	action, ok := ParsePTZAction(body.Action)
	if !ok {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid action"})
		return
	}
	id := chi.URLParam(r, "id")
	if err := h.svc.PTZ(r.Context(), id, action, time.Duration(body.DurationMS)*time.Millisecond); err != nil {
		h.fail(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"ok": true})
}

// switches: GET /cameras/{id}/switches -> {"privacy":false,"motion":true,...}
func (h *Handler) switches(w http.ResponseWriter, r *http.Request) {
	if !h.admit(w, r) {
		return
	}
	states, err := h.svc.SwitchStates(r.Context(), chi.URLParam(r, "id"))
	if err != nil {
		h.fail(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	httpx.JSON(w, http.StatusOK, states)
}

// setSwitch: PUT /cameras/{id}/switches/{key}   {"on":true}
func (h *Handler) setSwitch(w http.ResponseWriter, r *http.Request) {
	if !h.admit(w, r) {
		return
	}
	key, ok := ParseSwitchKey(chi.URLParam(r, "key"))
	if !ok {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid switch"})
		return
	}
	var body struct {
		On *bool `json:"on"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<10)).Decode(&body); err != nil || body.On == nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	id := chi.URLParam(r, "id")
	if err := h.svc.SetSwitch(r.Context(), id, key, *body.On); err != nil {
		h.fail(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{string(key): *body.On})
}

// status: GET /cameras/status. Always answers and costs no vendor call, so the
// app can tell "not set up" from "set up but offline".
func (h *Handler) status(w http.ResponseWriter, r *http.Request) {
	httpx.JSON(w, http.StatusOK, h.svc.Status())
}

// list: GET /cameras
func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	if !h.admit(w, r) {
		return
	}
	// ?refresh=1 skips the short cache (the app's refresh button).
	if r.URL.Query().Get("refresh") == "1" {
		h.svc.Refresh()
	}
	items, err := h.svc.List(r.Context())
	if err != nil {
		h.fail(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"items": items})
}

// live: GET /cameras/{id}/live?quality=hd|sd
func (h *Handler) live(w http.ResponseWriter, r *http.Request) {
	if !h.admit(w, r) {
		return
	}
	q, ok := ParseQuality(r.URL.Query().Get("quality"))
	if !ok {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid quality"})
		return
	}
	l, err := h.svc.Live(r.Context(), chi.URLParam(r, "id"), q)
	if err != nil {
		h.fail(w, err)
		return
	}
	// The address is a live-stream credential: never cache it.
	w.Header().Set("Cache-Control", "no-store")
	httpx.JSON(w, http.StatusOK, l)
}

// snapshot: GET /cameras/{id}/snapshot  (image bytes)
func (h *Handler) snapshot(w http.ResponseWriter, r *http.Request) {
	if !h.admit(w, r) {
		return
	}
	img, err := h.svc.Snapshot(r.Context(), chi.URLParam(r, "id"))
	if err != nil {
		h.fail(w, err)
		return
	}
	w.Header().Set("Content-Type", img.ContentType)
	w.Header().Set("Content-Length", strconv.Itoa(len(img.Data)))
	// Private (it is a picture of the home) and short-lived.
	w.Header().Set("Cache-Control", "private, max-age=10")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(img.Data)
}

// admit refuses a request when no camera source is configured. There is no
// per-user limit: this is one household.
func (h *Handler) admit(w http.ResponseWriter, r *http.Request) bool {
	if !h.svc.Enabled() {
		httpx.JSON(w, http.StatusServiceUnavailable, map[string]string{"error": "cameras_disabled"})
		return false
	}
	return true
}

// fail maps errors to responses. Vendor detail stays in our logs.
func (h *Handler) fail(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrDisabled):
		httpx.JSON(w, http.StatusServiceUnavailable, map[string]string{"error": "cameras_disabled"})
	case errors.Is(err, ErrProviderLimit):
		// Imou's own allowance, not a limit of ours.
		httpx.JSON(w, http.StatusTooManyRequests, map[string]string{"error": "provider_limit"})
	case errors.Is(err, ErrBadInput):
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid input"})
	case errors.Is(err, ErrNotFound):
		httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "camera_not_found"})
	case errors.Is(err, ErrOffline):
		httpx.JSON(w, http.StatusConflict, map[string]string{"error": "camera_offline"})
	case errors.Is(err, ErrUnsupported):
		httpx.JSON(w, http.StatusUnprocessableEntity, map[string]string{"error": "not_supported"})
	case errors.Is(err, ErrConfig):
		log.Printf("cameras: credentials rejected: %v", err)
		httpx.JSON(w, http.StatusServiceUnavailable, map[string]string{"error": "cameras_misconfigured"})
	case errors.Is(err, context.Canceled):
		// The client went away; nothing to send.
	default:
		log.Printf("cameras: upstream error: %v", err)
		httpx.JSON(w, http.StatusBadGateway, map[string]string{"error": "cameras_unavailable"})
	}
}

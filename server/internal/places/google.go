// Package places looks up nearby service businesses through Google's Places
// API (New).
//
// Rules this package is built around (Google Maps Platform terms):
//   - Nothing from Google is persisted. Results are returned to the caller and
//     forgotten; only a place_id may ever be stored by a caller.
//   - The API key lives only on the server and is never logged or returned.
//   - Pricing follows the *field mask*: list searches request only the cheaper
//     fields, and phone/rating/hours are fetched on demand by Details.
package places

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// DefaultBaseURL is Google's production endpoint. Overridable for tests and
// for pointing a dev server at a local fake.
const DefaultBaseURL = "https://places.googleapis.com"

// Field masks. Keep these minimal: each extra field can move the whole request
// to a more expensive SKU.
const (
	// listFieldMask is what a search needs to draw a result: identity, name,
	// where it is, what it is, and whether it is still operating.
	listFieldMask = "places.id,places.displayName,places.formattedAddress," +
		"places.location,places.types,places.businessStatus"

	// detailsFieldMask adds the contact/quality fields, fetched only when the
	// user opens one place.
	detailsFieldMask = "id,displayName,formattedAddress,location," +
		"nationalPhoneNumber,internationalPhoneNumber,rating,userRatingCount," +
		"regularOpeningHours.openNow,websiteUri,businessStatus"

	// basicDetailsFieldMask is what drawing a starred place in a list needs:
	// the same cheap fields as a search result, no contact/quality data.
	basicDetailsFieldMask = "id,displayName,formattedAddress,location,types,businessStatus"

	// googleMaxRadiusM is the largest bias circle Google accepts.
	googleMaxRadiusM = 50000.0
)

var (
	// ErrDisabled means no API key is configured. Callers should treat Google
	// as simply unavailable, not as a failure.
	ErrDisabled = errors.New("google places is not configured")

	// ErrUpstream wraps any failure talking to Google (network, quota,
	// permissions, bad response). Its text never contains the API key.
	ErrUpstream = errors.New("google places request failed")

	// ErrNotFound is returned by Details when Google has no such place.
	ErrNotFound = errors.New("place not found")
)

// Client is a thin HTTP client for the two Places calls we use.
type Client struct {
	apiKey  string
	baseURL string
	http    *http.Client
}

// NewClient returns a client. An empty apiKey is allowed: every call then
// returns ErrDisabled without touching the network.
func NewClient(apiKey, baseURL string) *Client {
	if baseURL == "" {
		baseURL = DefaultBaseURL
	}
	return &Client{
		apiKey:  strings.TrimSpace(apiKey),
		baseURL: strings.TrimRight(baseURL, "/"),
		http:    &http.Client{Timeout: 6 * time.Second},
	}
}

// Enabled reports whether an API key is configured.
func (c *Client) Enabled() bool { return c != nil && c.apiKey != "" }

// ── wire types ──────────────────────────────────────────────────────────────

type latLng struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type searchTextRequest struct {
	TextQuery      string        `json:"textQuery"`
	LanguageCode   string        `json:"languageCode,omitempty"`
	RegionCode     string        `json:"regionCode,omitempty"`
	MaxResultCount int           `json:"maxResultCount,omitempty"`
	LocationBias   *locationBias `json:"locationBias,omitempty"`
}

type locationBias struct {
	Circle circle `json:"circle"`
}

type circle struct {
	Center latLng  `json:"center"`
	Radius float64 `json:"radius"`
}

type googlePlace struct {
	ID          string `json:"id"`
	DisplayName struct {
		Text string `json:"text"`
	} `json:"displayName"`
	FormattedAddress         string   `json:"formattedAddress"`
	Location                 latLng   `json:"location"`
	Types                    []string `json:"types"`
	BusinessStatus           string   `json:"businessStatus"`
	NationalPhoneNumber      string   `json:"nationalPhoneNumber"`
	InternationalPhoneNumber string   `json:"internationalPhoneNumber"`
	Rating                   *float64 `json:"rating"`
	UserRatingCount          *int     `json:"userRatingCount"`
	WebsiteURI               string   `json:"websiteUri"`
	RegularOpeningHours      *struct {
		OpenNow *bool `json:"openNow"`
	} `json:"regularOpeningHours"`
}

type searchTextResponse struct {
	Places []googlePlace `json:"places"`
}

// ── calls ───────────────────────────────────────────────────────────────────

// searchText runs a Text Search biased towards a circle. Results are *biased*,
// not restricted, so callers must still filter by distance.
func (c *Client) searchText(
	ctx context.Context,
	query string,
	lat, lng, radiusM float64,
	max int,
) ([]googlePlace, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}

	body, err := json.Marshal(searchTextRequest{
		TextQuery:      query,
		LanguageCode:   "th",
		RegionCode:     "TH",
		MaxResultCount: max,
		LocationBias: &locationBias{Circle: circle{
			Center: latLng{Latitude: lat, Longitude: lng},
			Radius: radiusM,
		}},
	})
	if err != nil {
		return nil, fmt.Errorf("%w: encode request", ErrUpstream)
	}

	req, err := http.NewRequestWithContext(
		ctx, http.MethodPost, c.baseURL+"/v1/places:searchText", bytes.NewReader(body),
	)
	if err != nil {
		return nil, fmt.Errorf("%w: build request", ErrUpstream)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", c.apiKey)
	req.Header.Set("X-Goog-FieldMask", listFieldMask)

	var out searchTextResponse
	if err := c.do(req, &out); err != nil {
		return nil, err
	}
	return out.Places, nil
}

// details fetches one place with the given field mask.
func (c *Client) details(ctx context.Context, placeID, mask string) (*googlePlace, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}

	req, err := http.NewRequestWithContext(
		ctx, http.MethodGet,
		c.baseURL+"/v1/places/"+url.PathEscape(placeID)+"?languageCode=th&regionCode=TH",
		nil,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: build request", ErrUpstream)
	}
	req.Header.Set("X-Goog-Api-Key", c.apiKey)
	req.Header.Set("X-Goog-FieldMask", mask)

	var out googlePlace
	if err := c.do(req, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// do executes req and decodes a JSON 200 into dst. Errors are deliberately
// generic: Google's error bodies can echo request details we don't want to
// pass on.
func (c *Client) do(req *http.Request, dst any) error {
	resp, err := c.http.Do(req)
	if err != nil {
		// url.Error would include the URL; keep only the cause class.
		var ue *url.Error
		if errors.As(err, &ue) && ue.Timeout() {
			return fmt.Errorf("%w: timeout", ErrUpstream)
		}
		if errors.Is(err, context.Canceled) {
			return err
		}
		return fmt.Errorf("%w: network", ErrUpstream)
	}
	defer resp.Body.Close()

	switch {
	case resp.StatusCode == http.StatusNotFound:
		return ErrNotFound
	case resp.StatusCode < 200 || resp.StatusCode > 299:
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4<<10))
		return fmt.Errorf("%w: status %d", ErrUpstream, resp.StatusCode)
	}

	if err := json.NewDecoder(io.LimitReader(resp.Body, 2<<20)).Decode(dst); err != nil {
		return fmt.Errorf("%w: decode", ErrUpstream)
	}
	return nil
}

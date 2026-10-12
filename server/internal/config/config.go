package config

import (
	"log"
	"os"
	"strconv"
)

type Config struct {
	AppPort    string
	DSN        string
	JWTSecret  string
	CorsOrigin string

	StorageBackend string
	LocalDir       string
	PublicBaseURL  string

	// Google Places (optional). Empty key = feature off; the API then answers
	// 503 google_places_disabled and the app falls back to saved contractors.
	GooglePlacesAPIKey  string
	GooglePlacesBaseURL string // empty = Google's production endpoint

	// Bounds on Google traffic. Zero means "use the built-in default".
	GooglePlacesDailyLimit     int  // outbound calls per day, all users
	GooglePlacesRatePerMin     int  // requests per user per minute
	GooglePlacesMaxRadiusM     int  // largest accepted search radius
	GooglePlacesAllowAllTrades bool // permit a search with no trade and no text

	// Cloudflare R2
	R2AccountID string
	R2AccessKey string
	R2SecretKey string
	R2Bucket    string
	R2PublicURL string
}

func Getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func Getbool(key string, def bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return def
	}
	return b
}

// Getint reads an integer environment variable, falling back to def when it is
// unset or not a number.
func Getint(key string, def int) int {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}

func Load() Config {
	c := Config{
		AppPort:    Getenv("APP_PORT", "8080"),
		DSN:        Getenv("DB_DSN", "postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable"),
		JWTSecret:  Getenv("JWT_SECRET", "change-me"),
		CorsOrigin: Getenv("CORS_ALLOW_ORIGIN", "*"),

		StorageBackend: Getenv("STORAGE_BACKEND", "local"),
		LocalDir:       Getenv("LOCAL_STORAGE_DIR", "./data/uploads"),
		PublicBaseURL:  Getenv("PUBLIC_BASE_URL", "http://localhost:8080/static"),

		GooglePlacesAPIKey:  Getenv("GOOGLE_PLACES_API_KEY", ""),
		GooglePlacesBaseURL: Getenv("GOOGLE_PLACES_BASE_URL", ""),

		GooglePlacesDailyLimit:     Getint("GOOGLE_PLACES_DAILY_LIMIT", 0),
		GooglePlacesRatePerMin:     Getint("GOOGLE_PLACES_RATE_PER_MIN", 0),
		GooglePlacesMaxRadiusM:     Getint("GOOGLE_PLACES_MAX_RADIUS_M", 0),
		GooglePlacesAllowAllTrades: Getbool("GOOGLE_PLACES_ALLOW_ALL_TRADES", false),

		R2AccountID: Getenv("R2_ACCOUNT_ID", ""),
		R2AccessKey: Getenv("R2_ACCESS_KEY_ID", ""),
		R2SecretKey: Getenv("R2_SECRET_ACCESS_KEY", ""),
		R2Bucket:    Getenv("R2_BUCKET", ""),
		R2PublicURL: Getenv("R2_PUBLIC_URL", ""),
	}

	if c.JWTSecret == "change-me" {
		log.Println("[WARN] using default JWT secret; set JWT_SECRET in production")
	}

	return c
}

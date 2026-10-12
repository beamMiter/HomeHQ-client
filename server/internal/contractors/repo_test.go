package contractors

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Integration test for Repo.Search. It needs a Postgres that has the
// migrations applied; it is skipped unless TEST_DB_DSN is set:
//
//	TEST_DB_DSN='postgres://...' go test ./internal/contractors/...
func TestSearchDistance(t *testing.T) {
	dsn := os.Getenv("TEST_DB_DSN")
	if dsn == "" {
		t.Skip("TEST_DB_DSN not set")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	// Registered first so it runs last (Cleanup is LIFO): the DELETE cleanups
	// below still need an open pool. A plain `defer pool.Close()` would close
	// it before they run and leave the test rows behind.
	t.Cleanup(pool.Close)

	// created_by is a FK to users, so borrow any existing user.
	var userID string
	if err := pool.QueryRow(ctx, `SELECT id FROM users LIMIT 1`).Scan(&userID); err != nil {
		t.Skipf("need at least one user row to own the test data: %v", err)
	}

	const name = "__repo_test_contractor__"
	cleanup := func() {
		_, _ = pool.Exec(ctx, `DELETE FROM contractors WHERE name IN ($1, $2)`, name, name+" nocoords")
	}
	cleanup()
	t.Cleanup(cleanup)

	// One contractor with coordinates, one without (the old seed data looked like this).
	const lat, lng = 13.7455, 100.5342
	if _, err := pool.Exec(ctx, `
		INSERT INTO contractors (name, types, lat, lng, created_by)
		VALUES ($1, '{"plumber"}', $2, $3, $4), ($1 || ' nocoords', '{"plumber"}', NULL, NULL, $4)
	`, name, lat, lng, userID); err != nil {
		t.Fatalf("insert: %v", err)
	}

	repo := NewRepo(pool)
	search := func(t *testing.T, la, ln, radius float64) []ContractorSearchResult {
		t.Helper()
		got, err := repo.Search(ctx, SearchFilter{Query: name, Lat: &la, Lng: &ln, Radius: &radius, Limit: 10})
		if err != nil {
			t.Fatalf("Search: %v", err)
		}
		return got
	}

	t.Run("user standing exactly on the contractor", func(t *testing.T) {
		// Regression: acos() of a value a hair above 1 used to make Postgres
		// fail with "input is out of range" for identical coordinates.
		got := search(t, lat, lng, 1000)
		if len(got) != 1 {
			t.Fatalf("want 1 result, got %d", len(got))
		}
		if got[0].DistanceM == nil || *got[0].DistanceM > 1 {
			t.Fatalf("distance should be ~0 m, got %v", got[0].DistanceM)
		}
	})

	t.Run("outside radius returns empty list, not null", func(t *testing.T) {
		got := search(t, 37.3349, -122.0090, 5000) // Cupertino
		if got == nil {
			t.Fatal("want non-nil empty slice so JSON is [] not null")
		}
		if len(got) != 0 {
			t.Fatalf("want 0 results, got %d", len(got))
		}
	})

	t.Run("rows without coordinates never match a radius search", func(t *testing.T) {
		for _, c := range search(t, lat, lng, 1_000_000) {
			if c.Lat == nil || c.Lng == nil {
				t.Fatalf("%q has no coordinates but matched a radius search", c.Name)
			}
		}
	})
}

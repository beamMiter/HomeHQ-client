package places

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Integration test for PGStore. Needs a Postgres with migrations applied
// (including 00012_starred_places); skipped unless TEST_DB_DSN is set:
//
//	TEST_DB_DSN='postgres://...' go test ./internal/places/...
func TestPGStore(t *testing.T) {
	dsn := os.Getenv("TEST_DB_DSN")
	if dsn == "" {
		t.Skip("TEST_DB_DSN not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	// Registered first so it runs last: the cleanups below still need the pool.
	t.Cleanup(pool.Close)

	ids := []string{"__test_place_aaaa1", "__test_place_aaaa2", "__test_place_aaaa3"}
	cleanup := func() {
		_, _ = pool.Exec(ctx, `DELETE FROM starred_places WHERE place_id = ANY($1)`, ids)
	}
	cleanup()
	t.Cleanup(cleanup)

	s := NewPGStore(pool)

	// No user: created_by must be allowed to be empty.
	if err := s.Set(ctx, ids[0], "plumber", "", true); err != nil {
		t.Fatalf("star: %v", err)
	}
	if err := s.Set(ctx, ids[1], "", "", true); err != nil {
		t.Fatalf("star without trade: %v", err)
	}

	got, err := s.Starred(ctx, ids)
	if err != nil {
		t.Fatal(err)
	}
	if !got[ids[0]] || !got[ids[1]] || got[ids[2]] {
		t.Errorf("Starred = %v", got)
	}

	// Starring again without a label keeps the one we have; with one, updates it.
	_ = s.Set(ctx, ids[0], "", "", true)
	_ = s.Set(ctx, ids[1], "hvac", "", true)
	list, err := s.List(ctx, 50)
	if err != nil {
		t.Fatal(err)
	}
	trades := map[string]string{}
	for _, p := range list {
		trades[p.PlaceID] = p.Trade
	}
	if trades[ids[0]] != "plumber" {
		t.Errorf("label lost on re-star: %q", trades[ids[0]])
	}
	if trades[ids[1]] != "hvac" {
		t.Errorf("label not updated: %q", trades[ids[1]])
	}

	if err := s.Set(ctx, ids[0], "", "", false); err != nil {
		t.Fatal(err)
	}
	got, _ = s.Starred(ctx, ids)
	if got[ids[0]] {
		t.Errorf("unstar did not remove it")
	}
	if empty, err := s.Starred(ctx, nil); err != nil || len(empty) != 0 {
		t.Errorf("no ids should be a no-op: %v %v", empty, err)
	}
}

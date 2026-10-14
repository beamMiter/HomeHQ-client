package purchases

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// These run against a real database, so they only run when TEST_DB_DSN is set
// (the dev database is fine: every row made here is removed again).
//
//	TEST_DB_DSN='postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable' go test ./internal/purchases/
func testRepo(t *testing.T) (*pgxpool.Pool, Repo, string) {
	t.Helper()
	dsn := os.Getenv("TEST_DB_DSN")
	if dsn == "" {
		t.Skip("TEST_DB_DSN not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(pool.Close)

	var uid string
	email := fmt.Sprintf("purchases-test-%d@example.invalid", time.Now().UnixNano())
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (name, email, password_hash, role) VALUES ('t', $1, 'x', 'member') RETURNING id`,
		email).Scan(&uid); err != nil {
		t.Fatalf("make user: %v", err)
	}
	t.Cleanup(func() {
		c := context.Background()
		_, _ = pool.Exec(c, `DELETE FROM purchases WHERE requester_id = $1`, uid)
		_, _ = pool.Exec(c, `DELETE FROM users WHERE id = $1`, uid)
	})
	return pool, NewRepo(pool), uid
}

// The seed script (and any row made by hand) leaves note, category, store and
// buyer_id NULL. One such row used to make the whole list answer 500.
func TestListSurvivesNullColumns(t *testing.T) {
	pool, r, uid := testRepo(t)
	ctx := context.Background()

	if _, err := pool.Exec(ctx, `
		INSERT INTO purchases (title, items, currency, status, requester_id)
		VALUES ('null columns', '[]', 'THB', 'planned', $1)`, uid); err != nil {
		t.Fatal(err)
	}

	got, err := r.List(ctx, ListFilter{Mine: "requester", UserID: uid})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("want 1 purchase, got %d", len(got))
	}
	p := got[0]
	if p.Note != "" || p.Category != "" || p.Store != "" || p.BuyerID != "" {
		t.Errorf("unset columns should read as empty strings: %+v", p)
	}

	// The app needs an items list in every row, even an empty one.
	raw, _ := json.Marshal(p)
	if !strings.Contains(string(raw), `"items":[]`) {
		t.Errorf("a purchase with no items must send \"items\":[] , got %s", raw)
	}

	one, err := r.Get(ctx, p.ID)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if one.BuyerID != "" {
		t.Errorf("buyer should be empty, got %q", one.BuyerID)
	}
}

// What the app's form sends has no buyer, category or store. An empty string
// is not a uuid, so this used to fail with SQLSTATE 22P02.
func TestCreateWithoutBuyerCategoryStore(t *testing.T) {
	pool, r, uid := testRepo(t)
	ctx := context.Background()

	p := &Purchase{Title: "no buyer", RequesterID: uid, Items: Items{{Name: "x", Qty: 1}}}
	if err := r.Create(ctx, p); err != nil {
		t.Fatalf("create: %v", err)
	}
	if p.ID == "" || p.BuyerID != "" || p.Category != "" || p.Currency != "THB" {
		t.Errorf("unexpected created row: %+v", p)
	}

	// Stored as NULL, not as empty text.
	var nulls int
	if err := pool.QueryRow(ctx, `
		SELECT count(*) FROM purchases
		WHERE id = $1 AND category IS NULL AND store IS NULL AND buyer_id IS NULL`,
		p.ID).Scan(&nulls); err != nil {
		t.Fatal(err)
	}
	if nulls != 1 {
		t.Errorf("empty category/store/buyer should be stored as NULL")
	}
}

func TestUpdateClearsAndSetsBuyer(t *testing.T) {
	_, r, uid := testRepo(t)
	ctx := context.Background()

	p := &Purchase{Title: "update me", RequesterID: uid}
	if err := r.Create(ctx, p); err != nil {
		t.Fatal(err)
	}

	p.Category, p.Store, p.BuyerID = "food", "shop", uid
	if err := r.Update(ctx, p); err != nil {
		t.Fatalf("update: %v", err)
	}
	got, _ := r.Get(ctx, p.ID)
	if got.Category != "food" || got.Store != "shop" || got.BuyerID != uid {
		t.Errorf("values not saved: %+v", got)
	}

	p.Category, p.Store, p.BuyerID = "", "", ""
	if err := r.Update(ctx, p); err != nil {
		t.Fatalf("clearing: %v", err)
	}
	got, _ = r.Get(ctx, p.ID)
	if got.Category != "" || got.Store != "" || got.BuyerID != "" {
		t.Errorf("values not cleared: %+v", got)
	}
}

func TestEmptyListIsNotNil(t *testing.T) {
	_, r, uid := testRepo(t)
	got, err := r.List(context.Background(), ListFilter{Mine: "requester", UserID: uid})
	if err != nil {
		t.Fatal(err)
	}
	if got == nil {
		t.Error("an empty list must be [] (JSON), not null")
	}
}

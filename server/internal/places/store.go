package places

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

// StarredPlace is what we keep about a star: Google's id and our own label.
// Nothing else from Google is persisted.
type StarredPlace struct {
	PlaceID string
	Trade   string
}

// Store persists which places the household has starred.
type Store interface {
	// Starred reports which of ids are starred.
	Starred(ctx context.Context, ids []string) (map[string]bool, error)
	// Set stars or unstars one place. Idempotent.
	Set(ctx context.Context, placeID, trade, userID string, on bool) error
	// List returns starred places, newest first, at most limit.
	List(ctx context.Context, limit int) ([]StarredPlace, error)
}

// PGStore is the Postgres-backed Store.
type PGStore struct{ DB *pgxpool.Pool }

func NewPGStore(db *pgxpool.Pool) *PGStore { return &PGStore{DB: db} }

func (s *PGStore) Starred(ctx context.Context, ids []string) (map[string]bool, error) {
	out := map[string]bool{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := s.DB.Query(ctx, `SELECT place_id FROM starred_places WHERE place_id = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out[id] = true
	}
	return out, rows.Err()
}

func (s *PGStore) Set(ctx context.Context, placeID, trade, userID string, on bool) error {
	if !on {
		_, err := s.DB.Exec(ctx, `DELETE FROM starred_places WHERE place_id = $1`, placeID)
		return err
	}
	var uid any
	if userID != "" {
		uid = userID
	}
	_, err := s.DB.Exec(ctx, `
		INSERT INTO starred_places (place_id, trade, created_by)
		VALUES ($1, NULLIF($2, ''), $3)
		ON CONFLICT (place_id) DO UPDATE SET trade = COALESCE(NULLIF(EXCLUDED.trade, ''), starred_places.trade)
	`, placeID, trade, uid)
	return err
}

func (s *PGStore) List(ctx context.Context, limit int) ([]StarredPlace, error) {
	rows, err := s.DB.Query(ctx, `
		SELECT place_id, COALESCE(trade, '')
		FROM starred_places
		ORDER BY created_at DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []StarredPlace
	for rows.Next() {
		var p StarredPlace
		if err := rows.Scan(&p.PlaceID, &p.Trade); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

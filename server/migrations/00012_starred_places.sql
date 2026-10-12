-- +goose Up
-- Places the household has starred. Deliberately tiny: only Google's place_id
-- (which their terms allow storing) plus our own label. Names, addresses and
-- coordinates stay with Google and are fetched when needed.
CREATE TABLE starred_places (
  place_id   TEXT PRIMARY KEY,
  trade      TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE IF EXISTS starred_places;

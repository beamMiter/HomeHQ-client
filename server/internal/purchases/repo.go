package purchases

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ListFilter struct {
	Query    string
	Status   *Status
	Category string
	Mine     string
	UserID   string
	Limit    int
	Offset   int
}

type Repo interface {
	List(ctx context.Context, f ListFilter) ([]Purchase, error)
	Get(ctx context.Context, id string) (*Purchase, error)
	Create(ctx context.Context, p *Purchase) error
	Update(ctx context.Context, p *Purchase) error
	Delete(ctx context.Context, id string) error
	LinkAttachment(ctx context.Context, purchaseID, fileID string) error
	UnlinkAttachment(ctx context.Context, purchaseID, fileID string) error
}

type repo struct {
	DB *pgxpool.Pool
}

func NewRepo(db *pgxpool.Pool) Repo {
	return &repo{DB: db}
}

func jsonBytes(v any) []byte {
	if v == nil {
		return nil
	}
	b, _ := json.Marshal(v)
	return b
}

// note, category, store and buyer_id are nullable columns that the model holds
// as plain strings (empty = not set), so they are read through COALESCE. Without
// it one row with a NULL (every row the seed script makes) failed the whole
// list with "cannot scan NULL into *string".
const selectCols = `
  id, title, COALESCE(note, '') AS note, items, amount_estimated, amount_paid,
  currency, COALESCE(category, '') AS category, COALESCE(store, '') AS store,
  status, requester_id, COALESCE(buyer_id::text, '') AS buyer_id,
  editable_until, created_at, updated_at,
  COALESCE((SELECT array_agg(file_id::text) FROM purchase_attachments WHERE purchase_id = purchases.id), '{}') as attachments
`

func scanPurchase(row pgx.Row) (*Purchase, error) {
	var p Purchase
	if err := row.Scan(
		&p.ID, &p.Title, &p.Note, &p.Items,
		&p.AmountEstimated, &p.AmountPaid,
		&p.Currency, &p.Category, &p.Store,
		&p.Status, &p.RequesterID, &p.BuyerID,
		&p.EditableUntil, &p.CreatedAt, &p.UpdatedAt, &p.Attachments,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if p.Items == nil {
		p.Items = Items{} // [] in JSON, never null or missing
	}
	return &p, nil
}

func (r *repo) List(ctx context.Context, f ListFilter) ([]Purchase, error) {
	var sb strings.Builder
	var args []any
	arg := 1

	sb.WriteString(`SELECT ` + selectCols + ` FROM purchases WHERE 1=1`)

	if f.Query != "" {
		sb.WriteString(fmt.Sprintf(` AND (title ILIKE $%d OR note ILIKE $%d OR items::text ILIKE $%d)`, arg, arg, arg))
		args = append(args, "%"+f.Query+"%")
		arg++
	}
	if f.Status != nil && *f.Status != "" {
		sb.WriteString(fmt.Sprintf(` AND status = $%d`, arg))
		args = append(args, *f.Status)
		arg++
	}
	if f.Category != "" {
		sb.WriteString(fmt.Sprintf(` AND category = $%d`, arg))
		args = append(args, f.Category)
		arg++
	}
	if f.Mine == "requester" && f.UserID != "" {
		sb.WriteString(fmt.Sprintf(` AND requester_id = $%d`, arg))
		args = append(args, f.UserID)
		arg++
	}
	if f.Mine == "buyer" && f.UserID != "" {
		sb.WriteString(fmt.Sprintf(` AND buyer_id = $%d`, arg))
		args = append(args, f.UserID)
		arg++
	}

	limit := f.Limit
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	offset := f.Offset
	if offset < 0 {
		offset = 0
	}
	sb.WriteString(fmt.Sprintf(` ORDER BY created_at DESC LIMIT %d OFFSET %d`, limit, offset))

	rows, err := r.DB.Query(ctx, sb.String(), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	// Non-nil so an empty list is [] in JSON, not null.
	out := []Purchase{}
	for rows.Next() {
		var p Purchase
		if err := rows.Scan(
			&p.ID, &p.Title, &p.Note, &p.Items,
			&p.AmountEstimated, &p.AmountPaid,
			&p.Currency, &p.Category, &p.Store,
			&p.Status, &p.RequesterID, &p.BuyerID,
			&p.EditableUntil, &p.CreatedAt, &p.UpdatedAt, &p.Attachments,
		); err != nil {
			return nil, err
		}
		if p.Items == nil {
			p.Items = Items{}
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r *repo) Get(ctx context.Context, id string) (*Purchase, error) {
	row := r.DB.QueryRow(ctx, `SELECT `+selectCols+` FROM purchases WHERE id=$1`, id)
	return scanPurchase(row)
}

func (r *repo) Create(ctx context.Context, p *Purchase) error {
	if p.Currency == "" {
		p.Currency = "THB"
	}
	if p.Status == "" {
		p.Status = StatusPlanned
	}

	row := r.DB.QueryRow(ctx, `
		INSERT INTO purchases (
		  title, note, items, amount_estimated, amount_paid, currency,
		  category, store, status, requester_id, buyer_id
		) VALUES ($1,$2,$3,$4,$5,$6,NULLIF($7::text,''),NULLIF($8::text,''),$9,$10,NULLIF($11::text,'')::uuid)
		RETURNING id, title, COALESCE(note, ''), items, amount_estimated, amount_paid,
		currency, COALESCE(category, ''), COALESCE(store, ''), status, requester_id,
		COALESCE(buyer_id::text, ''),
		editable_until, created_at, updated_at, '{}'::text[] as attachments`,
		p.Title, p.Note, jsonBytes(p.Items),
		p.AmountEstimated, p.AmountPaid, p.Currency,
		p.Category, p.Store, p.Status, p.RequesterID, p.BuyerID,
	)
	result, err := scanPurchase(row)
	if err != nil {
		return err
	}
	*p = *result
	return nil
}

func (r *repo) Update(ctx context.Context, p *Purchase) error {
	_, err := r.DB.Exec(ctx, `
		UPDATE purchases
		SET title=$2, note=$3, items=$4, amount_estimated=$5, amount_paid=$6,
		    currency=$7, category=NULLIF($8::text,''), store=NULLIF($9::text,''),
		    status=$10, requester_id=$11, buyer_id=NULLIF($12::text,'')::uuid,
		    updated_at=now()
		WHERE id=$1
	`, p.ID, p.Title, p.Note, jsonBytes(p.Items),
		p.AmountEstimated, p.AmountPaid, p.Currency,
		p.Category, p.Store, p.Status, p.RequesterID, p.BuyerID)
	return err
}

func (r *repo) Delete(ctx context.Context, id string) error {
	_, err := r.DB.Exec(ctx, `DELETE FROM purchases WHERE id=$1`, id)
	return err
}

func (r *repo) LinkAttachment(ctx context.Context, purchaseID, fileID string) error {
	_, err := r.DB.Exec(ctx, `
		INSERT INTO purchase_attachments (purchase_id, file_id)
		VALUES ($1, $2) ON CONFLICT DO NOTHING
	`, purchaseID, fileID)
	return err
}

func (r *repo) UnlinkAttachment(ctx context.Context, purchaseID, fileID string) error {
	_, err := r.DB.Exec(ctx, `
		DELETE FROM purchase_attachments WHERE purchase_id=$1 AND file_id=$2
	`, purchaseID, fileID)
	return err
}
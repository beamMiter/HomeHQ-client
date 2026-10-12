package main

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

var adminID string

// Dev-only accounts. NEVER run this seed against a production database: the
// passwords below are public and are reset on every run.
//
//	admin@example.com / admin2026  (role: admin)
//	user@example.com  / user2026   (role: member)
//
// The bcrypt hashes were generated with internal/auth.HashPassword.
const (
	adminSeedPasswordHash  = "$2a$10$MBI7b.EBgddh9Cy.TbbZ5.vzH/r2upikoz.biGTRsSj9wK0W3s7Xu"
	memberSeedPasswordHash = "$2a$10$pXSZFF3Vg4lqL.fhoxenx.ay11NGjg/pC9l7PEsQ9HesB.JZcGIg2"
)

func seedUsers(ctx context.Context, db *pgxpool.Pool) {
	accounts := []struct {
		name, email, hash, role string
	}{
		{"Admin", "admin@example.com", adminSeedPasswordHash, "admin"},
		{"User", "user@example.com", memberSeedPasswordHash, "member"},
	}

	for _, a := range accounts {
		var id string
		err := db.QueryRow(ctx, `
			INSERT INTO users (name, email, password_hash, role)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (email) DO UPDATE SET name = $1, role = $4, password_hash = $3
			RETURNING id
		`, a.name, a.email, a.hash, a.role).Scan(&id)
		if err != nil {
			log.Fatalf("seedUsers %s: %v", a.email, err)
		}
		if a.role == "admin" {
			adminID = id // owner of the rest of the seed data
		}
		log.Printf("✅ user seeded: %s (%s)", a.email, a.role)
	}
}

func seedNotes(ctx context.Context, db *pgxpool.Pool) {
	notes := []struct {
		title, content, category string
		pinned                   bool
	}{
		{"ซื้อหลอดไฟ", "ห้องนอนใหญ่ไฟขาด", "general", true},
		{"นัดหมอ", "วันศุกร์ 10:00 โรงพยาบาล", "appointment", false},
		{"จ่ายค่าน้ำ", "ครบกำหนดสิ้นเดือน", "bills", false},
	}
	for _, n := range notes {
		_, err := db.Exec(ctx, `
			INSERT INTO notes (user_id, title, content, category, pinned)
			VALUES ($1, $2, $3, $4, $5)
		`, adminID, n.title, n.content, n.category, n.pinned)
		if err != nil {
			log.Printf("seedNotes: %v", err)
		}
	}
	log.Println("✅ notes seeded")
}

func seedChores(ctx context.Context, db *pgxpool.Pool) {
	chores := []struct {
		title, category string
	}{
		{"ล้างจาน", "kitchen"},
		{"กวาดบ้าน", "general"},
		{"ล้างห้องน้ำ", "bathroom"},
		{"ตัดหญ้า", "outdoor"},
	}
	for _, c := range chores {
		_, err := db.Exec(ctx, `
			INSERT INTO chores (title, category, created_by)
			VALUES ($1, $2, $3)
		`, c.title, c.category, adminID)
		if err != nil {
			log.Printf("seedChores: %v", err)
		}
	}
	log.Println("✅ chores seeded")
}

func seedBills(ctx context.Context, db *pgxpool.Pool) {
	bills := []struct {
		billType, title string
		amount          float64
		status          string
	}{
		{"electric", "ค่าไฟเดือนนี้", 1200.00, "unpaid"},
		{"water", "ค่าน้ำเดือนนี้", 350.00, "unpaid"},
		{"internet", "ค่าเน็ต", 590.00, "paid"},
	}
	for _, b := range bills {
		_, err := db.Exec(ctx, `
			INSERT INTO bills (type, title, amount, due_date, status, created_by)
			VALUES ($1, $2, $3, now() + INTERVAL '7 days', $4, $5)
		`, b.billType, b.title, b.amount, b.status, adminID)
		if err != nil {
			log.Printf("seedBills: %v", err)
		}
	}
	log.Println("✅ bills seeded")
}

func seedPurchases(ctx context.Context, db *pgxpool.Pool) {
	_, err := db.Exec(ctx, `
		INSERT INTO purchases (title, note, items, amount_estimated, currency, status, requester_id)
		VALUES 
		('ซื้ออุปกรณ์ทำความสะอาด', 'น้ำยาถูพื้น + ไม้กวาด', '[]', 500.00, 'THB', 'planned', $1),
		('หลอดไฟ LED', 'ห้องนอน 3 หลอด', '[]', 250.00, 'THB', 'bought', $1)
	`, adminID)
	if err != nil {
		log.Printf("seedPurchases: %v", err)
	}
	log.Println("✅ purchases seeded")
}

func seedMedicine(ctx context.Context, db *pgxpool.Pool) {
	medicines := []struct {
		name, form, unit, category string
		qty                        float64
	}{
		{"Paracetamol 500mg", "tablet", "tab", "painkiller", 20},
		{"Cetirizine", "tablet", "tab", "antihistamine", 10},
		{"น้ำเกลือล้างแผล", "liquid", "ml", "wound care", 500},
	}
	for _, m := range medicines {
		_, err := db.Exec(ctx, `
			INSERT INTO medicine_items (name, form, unit, category, stock_qty)
			VALUES ($1, $2, $3, $4, $5)
		`, m.name, m.form, m.unit, m.category, m.qty)
		if err != nil {
			log.Printf("seedMedicine: %v", err)
		}
	}
	log.Println("✅ medicine seeded")
}

// seedContractors inserts sample contractors around central Bangkok, one or
// more per trade the app filters on.
// Coordinates matter: the radius search filters on lat/lng IS NOT NULL, so rows
// without them can never be found. Safe to re-run — existing rows are kept and
// only get their coordinates backfilled if they were seeded without any.
func seedContractors(ctx context.Context, db *pgxpool.Pool) {
	rows := []struct {
		name, typ, phone, note, address string
		fav                             bool
		lat, lng                        float64
	}{
		{"ช่างอ้น", "electrician", "0812345678", "ช่างไฟแนะนำ", "ถนนพญาไท, ราชเทวี, กรุงเทพฯ", true, 13.7512, 100.5410},
		{"ช่างประปาแถวบ้าน", "plumber", "0898765432", "", "อนุสาวรีย์ชัยสมรภูมิ, ราชเทวี, กรุงเทพฯ", false, 13.7649, 100.5383},
		{"ช่างสมชาย แอร์เซอร์วิส", "hvac", "0861234567", "ล้าง/ซ่อมแอร์", "ถนนพระราม 4, ปทุมวัน, กรุงเทพฯ", false, 13.7380, 100.5290},
		{"ช่างไม้ลุงแดง", "carpenter", "0829876543", "งานไม้/เฟอร์นิเจอร์", "ถนนเพชรบุรี, ราชเทวี, กรุงเทพฯ", false, 13.7570, 100.5255},
	}

	for _, c := range rows {
		_, err := db.Exec(ctx, `
			INSERT INTO contractors (name, types, phone, note, address, lat, lng, is_favorite, created_by)
			SELECT $1::text, ARRAY[$2::text], $3::text, $4::text, $5::text,
			       $6::float8, $7::float8, $8::boolean, $9::uuid
			WHERE NOT EXISTS (SELECT 1 FROM contractors WHERE name = $1::text)
		`, c.name, c.typ, c.phone, c.note, c.address, c.lat, c.lng, c.fav, adminID)
		if err != nil {
			log.Printf("seedContractors insert %q: %v", c.name, err)
			continue
		}
		if _, err := db.Exec(ctx, `
			UPDATE contractors SET lat = $2::float8, lng = $3::float8, address = COALESCE(address, $4::text)
			WHERE name = $1::text AND lat IS NULL AND lng IS NULL
		`, c.name, c.lat, c.lng, c.address); err != nil {
			log.Printf("seedContractors backfill %q: %v", c.name, err)
		}
	}
	log.Println("✅ contractors seeded")
}

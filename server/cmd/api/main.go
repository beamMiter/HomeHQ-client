package main

import (
	"context"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/bills"
	"github.com/iMookatayou/homeservice-backend/internal/cameras"
	"github.com/iMookatayou/homeservice-backend/internal/chores"
	"github.com/iMookatayou/homeservice-backend/internal/config"
	"github.com/iMookatayou/homeservice-backend/internal/contractors"
	"github.com/iMookatayou/homeservice-backend/internal/db"
	"github.com/iMookatayou/homeservice-backend/internal/files"
	"github.com/iMookatayou/homeservice-backend/internal/health"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
	"github.com/iMookatayou/homeservice-backend/internal/medicine"
	"github.com/iMookatayou/homeservice-backend/internal/notes"
	"github.com/iMookatayou/homeservice-backend/internal/places"
	"github.com/iMookatayou/homeservice-backend/internal/purchases"
	"github.com/iMookatayou/homeservice-backend/internal/storage"
	"github.com/iMookatayou/homeservice-backend/internal/user"
)

func main() {
	cfg := config.Load()
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	ctx := context.Background()
	pool, err := db.Connect(ctx, cfg.DSN)
	if err != nil {
		logger.Fatal("db connect", zap.Error(err))
	}
	defer pool.Close()

	// Users & Auth
	uRepo := user.Repo{DB: pool}
	uHandler := user.Handler{Repo: uRepo, JWTSecret: cfg.JWTSecret}

	// Notes
	nRepo := notes.Repo{DB: pool}
	nHandler := notes.Handler{Repo: nRepo}

	// Files
	st := storage.New(cfg)
	fRepo := files.Repo{DB: pool}
	fHandler := files.Handler{Repo: fRepo, Storage: st, JWTSecret: cfg.JWTSecret}

	// Purchases
	pRepo := purchases.NewRepo(pool)
	pSvc := purchases.NewService(pRepo)
	pHandler := purchases.Handler{Svc: pSvc}

	// Bills
	bRepo := bills.Repo{DB: pool}
	bSvc := bills.NewService(bRepo)
	bHandler := bills.Handler{Svc: bSvc}

	// Contractors
	ctrRepo := contractors.NewRepo(pool)
	ctrSvc := contractors.NewService(ctrRepo)
	ctrH := contractors.NewHandler(ctrSvc)

	// Google Places (off unless GOOGLE_PLACES_API_KEY is set)
	placesLimits := places.DefaultLimits()
	if cfg.GooglePlacesDailyLimit > 0 {
		placesLimits.DailyCalls = cfg.GooglePlacesDailyLimit
	}
	if cfg.GooglePlacesRatePerMin > 0 {
		placesLimits.RatePerMin = cfg.GooglePlacesRatePerMin
	}
	if cfg.GooglePlacesMaxRadiusM > 0 {
		placesLimits.MaxRadiusM = float64(cfg.GooglePlacesMaxRadiusM)
	}
	placesLimits.AllowAllTrades = cfg.GooglePlacesAllowAllTrades
	placesSvc := places.NewService(
		places.NewClient(cfg.GooglePlacesAPIKey, cfg.GooglePlacesBaseURL),
		places.NewPGStore(pool),
		placesLimits,
	)
	placesH := places.NewHandler(placesSvc)
	if !placesSvc.Enabled() {
		logger.Info("google places disabled: GOOGLE_PLACES_API_KEY not set")
	}

	// Cameras (off unless an Imou account is configured, or CAMERAS_DRIVER=fake)
	var camDriver cameras.Driver
	switch kind := cfg.CamerasDriver; {
	case kind == "fake":
		camDriver = cameras.NewFake(cfg.CamerasFakeStreamURL)
	case kind == "imou" || (kind == "" && cfg.ImouAppID != "" && cfg.ImouAppSecret != ""):
		camDriver = cameras.NewImou(cameras.ImouConfig{
			AppID:     cfg.ImouAppID,
			AppSecret: cfg.ImouAppSecret,
			BaseURL:   cfg.ImouBaseURL,
			Region:    cfg.ImouRegion,
		})
	}
	camSvc := cameras.NewService(camDriver)
	camH := cameras.NewHandler(camSvc)
	if camSvc.Enabled() {
		logger.Info("cameras enabled", zap.String("driver", camDriver.Name()))
	} else {
		logger.Info("cameras disabled: set IMOU_APP_ID/IMOU_APP_SECRET (or CAMERAS_DRIVER=fake)")
	}

	// Medicine
	mRepo := medicine.NewRepo(pool)
	mSvc := medicine.NewService(mRepo)
	mHandler := medicine.NewHandler(mSvc)

	// Chores
	choresHandler := chores.Handler{Repo: chores.Repo{DB: pool}}

	// Router
	r := chi.NewRouter()
	for _, m := range httpx.CommonMiddlewares(cfg.CorsOrigin) {
		r.Use(m)
	}

	r.Get("/healthz", health.Live)
	r.Get("/readyz", health.Ready)

	r.Route("/api/v1", func(api chi.Router) {
		// Public
		api.Post("/auth/register", uHandler.Register)
		api.Post("/auth/login", uHandler.Login)
		api.Post("/auth/refresh", uHandler.Refresh)
		api.Post("/auth/forgot-password", uHandler.ForgotPassword)
		api.Post("/auth/reset-password", uHandler.ResetPassword)

		// Auth required
		api.Group(func(pr chi.Router) {
			pr.Use(auth.RequireAuth(cfg.JWTSecret, auth.NewClaims))

			pr.Get("/me", uHandler.Me)
			pr.Patch("/me", uHandler.UpdateProfile)
			pr.Post("/me/password", uHandler.ChangePassword)
			pr.Post("/auth/logout", uHandler.Logout)

			nHandler.RegisterRoutes(pr)
			fHandler.RegisterRoutes(pr)
			choresHandler.RegisterRoutes(pr)
			pHandler.RegisterRoutes(pr)
			bHandler.RegisterRoutes(pr)

			pr.Route("/medicine", func(r chi.Router) {
				mHandler.RegisterRoutes(r)
			})

			pr.Route("/contractors", func(r chi.Router) {
				ctrH.RegisterRoutes(r)
			})

			pr.Route("/places", func(r chi.Router) {
				placesH.RegisterRoutes(r)
			})

			pr.Route("/cameras", func(r chi.Router) {
				camH.RegisterRoutes(r)
			})
		})
	})

	srv := &http.Server{
		Addr:              ":" + cfg.AppPort,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}
	logger.Info("listening", zap.String("addr", srv.Addr))
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Fatal("server", zap.Error(err))
	}
}

package db

import (
	"log"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

func Connect() {
	// For dev, we hardcode these. In prod, use os.Getenv()
	dsn := os.Getenv("DATABASE_DSN")
	if dsn == "" {
		// Fallback for local dev
		dsn = "host=localhost user=rivulet password=password dbname=rivulet_db port=5432 sslmode=disable TimeZone=UTC"
	}

	var err error
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("❌ Failed to connect to database:", err)
	}

	log.Println("✅ Connected to PostgreSQL")

	// Auto-Migrate Schemas
	log.Println("⚙️ Running Migrations...")
	err = DB.AutoMigrate(
		// auth
		&Account{},
		&AccountRefreshToken{},
		&AccountAddons{},
		&UserProfile{},
		&FavoriteStream{},
		&Library{},
		&LibraryEntry{},
		&MediaProgress{},
		&WatchedMedia{},
	)
	if err != nil {
		log.Fatal("❌ Migration failed:", err)
	}
	log.Println("✅ Migrations Complete")
}

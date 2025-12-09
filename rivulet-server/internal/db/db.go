package db

import (
	// "fmt"
	"log"
	// "os"
	"rivulet_server/internal/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

func Connect() {
	// For dev, we hardcode these. In prod, use os.Getenv()
	dsn := "host=localhost user=rivulet password=password dbname=rivulet_db port=5432 sslmode=disable TimeZone=UTC"

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
		&models.Account{},
		&models.Profile{},
		
		// media
		&models.Movie{},
		&models.Series{},
		&models.Season{},
		&models.Episode{},
		&models.Person{},
		&models.Credit{},
		&models.Image{},
		
		// library
		&models.LibraryEntry{},
		&models.MediaProgress{},
	)
	if err != nil {
		log.Fatal("❌ Migration failed:", err)
	}
	log.Println("✅ Migrations Complete")
}
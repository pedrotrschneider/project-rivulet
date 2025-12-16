package models

import (
	"github.com/google/uuid"
)

type FavoriteTorrent struct {
	Base
	ProfileID uuid.UUID `gorm:"type:uuid;index;not null"`
	MediaID   string    `gorm:"index;not null"` // External ID (e.g. "tt123" or "tmdb:123")
	Hash      string    `gorm:"index;not null"` // Magnet hash
}

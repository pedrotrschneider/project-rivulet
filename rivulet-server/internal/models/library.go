package models

import (
	"time"
	"github.com/google/uuid"
)

// LibraryEntry links a specific Media item to a User Profile.
// This allows multiple users to have different "My Lists".
type LibraryEntry struct {
	Base
	ProfileID uuid.UUID `gorm:"type:uuid;uniqueIndex:idx_profile_media;not null"`
	
	// Polymorphic link to Movie or Series (we don't add episodes to library individually usually)
	MediaType string    `gorm:"uniqueIndex:idx_profile_media;not null"` // "Movie" or "Series"
	MediaID   uuid.UUID `gorm:"type:uuid;uniqueIndex:idx_profile_media;not null"`
	
	// Overrides (User can rename items or change posters)
	CustomTitle    string
	CustomPosterID *uuid.UUID `gorm:"type:uuid"`
}

// MediaProgress tracks playback.
type MediaProgress struct {
	Base
	ProfileID uuid.UUID `gorm:"type:uuid;uniqueIndex:idx_prog_profile_media;not null"`
	
	// What are we watching?
	MediaID   *uuid.UUID `gorm:"type:uuid;uniqueIndex:idx_prog_profile_media"`
	EpisodeID *uuid.UUID `gorm:"type:uuid;uniqueIndex:idx_prog_profile_media"`
	
	PositionTicks int64 // Stored in ticks (10,000 ticks = 1ms) or seconds, up to you.
	DurationTicks int64
	IsWatched     bool
	LastPlayedAt  time.Time
}
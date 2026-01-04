package db

import (
	"time"

	"github.com/google/uuid"
)

// Base model with UUID primary key
type Base struct {
	Id        uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Role int

const (
	RoleUser Role = iota
	RoleAdmin
)

func (r Role) ToString() string {
	switch r {
	case RoleUser:
		return "User"
	case RoleAdmin:
		return "Admin"
	default:
		return "Unknown"
	}
}

// Admin Account table and User Account table

type Account struct {
	Base
	
	// Compound index. Same e-mail can be an admin and a user
	Email        string `gorm:"uniqueIndex:idx_account_unique;not null"`
	Role         Role   `gorm:"uniqueIndex:idx_account_unique;not null"`
	
	PasswordHash string `gorm:"not null"`
}

// Admin Account Refresh Token table / User Account Refresh Token table

type AccountRefreshToken struct {
	Base
	AccountId uuid.UUID `gorm:"type:uuid;index;not null"`
	TokenHash string    `gorm:"uniqueIndex;not null"`
	FamilyId  uuid.UUID `gorm:"type:uuid;index;not null"`
	IsRevoked bool      `gorm:"not null"`
	ExpiresAt time.Time `gorm:"not null"`

	DeviceName string `gorm:"not null"`
	IpAddress  string `gorm:"not null"`
}

// Account Addons table

type AccountAddons struct {
	Base
	AccountId   uuid.UUID `gorm:"type:uuid;index;not null"`
	ManifestUrl string    `gorm:"not null"`
	Priority    int       `gorm:"default:0"` // For sorting addon results
}

// User Profile table

type UserProfile struct {
	Base
	AccountId uuid.UUID `gorm:"type:uuid;index;not null"`
	Name      string    `gorm:"not null"`
	Avatar    string
}

// Favorite Stream table

type FavoriteStream struct {
	Base
	ProfileId uuid.UUID `gorm:"type:uuid;index;not null"`
	ImdbId    string    `gorm:"index;not null"`
	AddonId   string    `gorm:"index;not null"`
	TitleHash string    `gorm:"index;not null"`
}

// Libraries Table

type Library struct {
	Base
	ProfileID uuid.UUID `gorm:"type:uuid;index;not null"`
	Name      string    `gorm:"index;not null"`
}

// Library Entries Table

type LibraryEntry struct {
	Base
	LibraryId uuid.UUID `gorm:"type:uuid;index;not null"`
	ImdbId    string    `gorm:"index;not null"`
	Type      string    `gorm:"index;not null"` // movie or series
}

// Media Progress Table

type MediaProgress struct {
	Base

	// Compound index
	ProfileId uuid.UUID `gorm:"type:uuid;uniqueIndex:idx_media_progress_unique;not null"`
	ImdbId    string    `gorm:"uniqueIndex:idx_media_progress_unique;not null"`
	Type      string    `gorm:"uniqueIndex:idx_media_progress_unique;not null"` // movie or series
	Season    int       `gorm:"uniqueIndex:idx_media_progress_unique;default:0"`
	Episode   int       `gorm:"uniqueIndex:idx_media_progress_unique;default:0"`

	PositionTicks int64
	DurationTicks int64
	LastPlayedAt  time.Time
}

// Watched Media Table

type WatchedMedia struct {
	Base

	// Compound index
	ProfileId uuid.UUID `gorm:"type:uuid;uniqueIndex:idx_media_progress_unique;not null"`
	Type      string    `gorm:"uniqueIndex:idx_media_progress_unique;not null"` // movie or series
	ImdbId    string    `gorm:"uniqueIndex:idx_media_progress_unique;not null"`
	Season    int       `gorm:"uniqueIndex:idx_media_progress_unique;default:0"`
	Episode   int       `gorm:"uniqueIndex:idx_media_progress_unique;default:0"`
}

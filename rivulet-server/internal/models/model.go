package models

import (
	"time"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Base model with UUID primary key
type Base struct {
	ID        uuid.UUID      `gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CreatedAt time.Time
	UpdatedAt time.Time
	DeletedAt gorm.DeletedAt `gorm:"index"`
}

type Account struct {
	Base
	Email         string `gorm:"uniqueIndex;not null"`
	PasswordHash  string `gorm:"not null"`
	IsAdmin       bool `gorm:"default:false"`
	Profiles      []Profile

	// API Keys
	RealDebridKey string 
	TMDbKey       string 
	MDBListKey    string

	// OTP Logic (Stored in DB for simplicity)
	CurrentOtp   string    `json:"-"`
	OtpExpiresAt time.Time `json:"-"`
}

type Profile struct {
	Base
	AccountID uuid.UUID `gorm:"type:uuid;not null"`
	Name      string    `gorm:"not null"`
	Avatar    string
}
package models

import (
	"time"
	"github.com/google/uuid"
)

// --- Core Media Types ---

type Movie struct {
	Base
	Title            string         `gorm:"index;not null"`
	Overview         string         `gorm:"type:text"`
	ExternalIDs      map[string]any `gorm:"serializer:json"` // Stores {"tmdb": 123, "imdb": "tt..."}
	MetadataSource   string         `gorm:"default:'manual'"`
	ReleaseDate      *time.Time
	Runtime          int    // In minutes
	OriginalLanguage string
	Images           []Image `gorm:"polymorphic:Owner;"`
	Credits          []Credit `gorm:"polymorphic:Media;"`
}

type Series struct {
	Base
	Title         string         `gorm:"index;not null"`
	Overview      string         `gorm:"type:text"`
	Status        string         // "Ended", "Returning Series"
	ContentRating string         // "TV-MA", "TV-14"
	ExternalIDs   map[string]any `gorm:"serializer:json"`
	Seasons       []Season
	Images        []Image `gorm:"polymorphic:Owner;"`
	Credits       []Credit `gorm:"polymorphic:Media;"`
}

type Season struct {
	Base
	SeriesID     uuid.UUID      `gorm:"type:uuid;index;not null"`
	SeasonNumber int            `gorm:"not null"`
	Title        string
	Overview     string         `gorm:"type:text"`
	ExternalIDs  map[string]any `gorm:"serializer:json"`
	Episodes     []Episode
	Images       []Image `gorm:"polymorphic:Owner;"`
}

type Episode struct {
	Base
	SeriesID      uuid.UUID      `gorm:"type:uuid;index;not null"`
	SeasonID      uuid.UUID      `gorm:"type:uuid;index;not null"`
	EpisodeNumber int            `gorm:"not null"`
	Title         string
	Overview      string         `gorm:"type:text"`
	AirDate       *time.Time
	Runtime       int
	ExternalIDs   map[string]any `gorm:"serializer:json"`
	StillImage    Image          `gorm:"polymorphic:Owner;"`
}

// --- People & Credits ---

type Person struct {
	Base
	Name             string         `gorm:"index;not null"`
	Biography        string         `gorm:"type:text"`
	BirthDate        *time.Time
	PlaceOfBirth     string
	ProfileImagePath string         // Local path to headshot
	ExternalIDs      map[string]any `gorm:"serializer:json"`
}

type Credit struct {
	Base
	MediaType     string    `gorm:"index"` // "Movie" or "Series"
	MediaID       uuid.UUID `gorm:"type:uuid;index"`
	PersonID      uuid.UUID `gorm:"type:uuid;index;not null"`
	Role          string    // "Actor", "Director", "Writer"
	CharacterName string
	Order         int       // For sorting cast lists
}

// --- Assets ---

type Image struct {
	Base
	OwnerType string    `gorm:"index"` // "Movie", "Series", "Season", "Person"
	OwnerID   uuid.UUID `gorm:"type:uuid;index"`
	Type      string    // "poster", "backdrop", "logo", "still"
	SourceURL string
	LocalPath string
}
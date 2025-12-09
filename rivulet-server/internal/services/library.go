package services

import (
	"fmt"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"rivulet_server/internal/providers/mdblist"
	"rivulet_server/internal/providers/tmdb"
	"strings"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AddToLibrary handles the entire flow of adding media
func AddToLibrary(mdbClient *mdblist.Client, tmdbClient *tmdb.Client, mdbApiKey, tmdbApiKey, externalID, mediaType string, profileID uuid.UUID) error {
	// 1. Determine Type and ID
	// MDBList expects "tt..." or "tm..."
	// We assume externalID format: "imdb:tt123" or "tmdb:123" or just "tt123"
	cleanID := externalID

	if strings.Contains(externalID, ":") {
		parts := strings.Split(externalID, ":")
		cleanID = parts[1]
		// Heuristic: If user explicitly passed type context from FE, we might need to handle that.
		// For now, let MDBList figure it out or pass explicit type if your FE sends it.
	}

	// 2. Check if already exists in DB (Avoid re-fetching)
	// This uses GORM's JSON querying capabilities
	var existingMovie models.Movie
	var existingSeries models.Series

	// Try finding movie
	err := db.DB.Where("external_ids ->> 'imdb' = ? OR external_ids ->> 'tmdb' = ?", cleanID, cleanID).First(&existingMovie).Error
	if err == nil {
		return linkToProfile(existingMovie.ID, mediaType, profileID)
	}

	// Try finding series
	err = db.DB.Where("external_ids ->> 'imdb' = ? OR external_ids ->> 'tmdb' = ?", cleanID, cleanID).First(&existingSeries).Error
	if err == nil {
		return linkToProfile(existingSeries.ID, mediaType, profileID)
	}

	// 3. Fetch from MDBList
	details, err := mdbClient.GetDetails(mdbApiKey, cleanID, mediaType)
	if err != nil {
		return fmt.Errorf("metadata not found: %v", err)
	}

	// 4. Download Images
	posterPath, _ := DownloadImage(details.Poster)
	backdropPath, _ := DownloadImage(details.Backdrop)

	var logoPath string
	if details.TmdbID != 0 {
		// Determine type for TMDB call
		tmType := "movie"
		if mediaType != "movie" {
			tmType = "tv"
		}

		logoURL, err := tmdbClient.GetLogo(tmdbApiKey, details.TmdbID, tmType)
		if err == nil && logoURL != "" {
			logoPath, _ = DownloadImage(logoURL)
		}
	}

	// 5. Save to DB
	if mediaType == "movie" {
		movie := models.Movie{
			Title:          details.Title,
			Overview:       details.Description,
			MetadataSource: "mdblist",
			ExternalIDs:    map[string]any{"imdb": details.ImdbID, "tmdb": details.TmdbID},
			// Parse Year/Date properly in production
		}

		// Create DB transaction
		err = db.DB.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&movie).Error; err != nil {
				return err
			}
			// Save Images
			if posterPath != "" {
				tx.Create(&models.Image{OwnerType: "Movie", OwnerID: movie.ID, Type: "poster", LocalPath: posterPath, SourceURL: details.Poster})
			}
			if backdropPath != "" {
				tx.Create(&models.Image{OwnerType: "Movie", OwnerID: movie.ID, Type: "backdrop", LocalPath: backdropPath, SourceURL: details.Backdrop})
			}
			if logoPath != "" {
				tx.Create(&models.Image{OwnerType: "Movie", OwnerID: movie.ID, Type: "logo", LocalPath: logoPath, SourceURL: ""})
			}
			return nil
		})
		if err != nil {
			return err
		}
		return linkToProfile(movie.ID, mediaType, profileID)

	} else {
		// Is Series
		series := models.Series{
			Title:       details.Title,
			Overview:    details.Description,
			ExternalIDs: map[string]any{"imdb": details.ImdbID, "tmdb": details.TmdbID},
		}

		err = db.DB.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&series).Error; err != nil {
				return err
			}
			if posterPath != "" {
				tx.Create(&models.Image{OwnerType: "Series", OwnerID: series.ID, Type: "poster", LocalPath: posterPath, SourceURL: details.Poster})
			}
			if backdropPath != "" {
				tx.Create(&models.Image{OwnerType: "Series", OwnerID: series.ID, Type: "backdrop", LocalPath: backdropPath, SourceURL: details.Backdrop})
			}
			if logoPath != "" {
				tx.Create(&models.Image{OwnerType: "Series", OwnerID: series.ID, Type: "logo", LocalPath: logoPath, SourceURL: ""})
			}

			if details.TmdbID != 0 {
				tmdbShow, err := tmdbClient.GetTVShowDetails(tmdbApiKey, details.TmdbID)
				if err != nil || tmdbShow == nil {
					return err
				}
				for _, s := range tmdbShow.Seasons {
					// A. Download Season Poster
					var seasonPosterPath string
					if s.PosterPath != "" {
						// TMDB returns relative path, need to prepend base
						fullUrl := "https://image.tmdb.org/t/p/w500" + s.PosterPath
						seasonPosterPath, _ = DownloadImage(fullUrl)
					}

					// B. Create Season Record
					season := models.Season{
						SeriesID:     series.ID,
						SeasonNumber: s.SeasonNumber,
						Title:        s.Name,
						Overview:     s.Overview,
						ExternalIDs:  map[string]any{"tmdb": s.ID},
					}
					if err := tx.Create(&season).Error; err != nil {
						continue // Skip failed season but keep going
					}

					// C. Save Season Image
					if seasonPosterPath != "" {
						tx.Create(&models.Image{
							OwnerType: "Season",
							OwnerID:   season.ID,
							Type:      "poster",
							LocalPath: seasonPosterPath,
						})
					}
				}
			}

			return nil
		})
		if err != nil {
			return err
		}
		return linkToProfile(series.ID, mediaType, profileID)
	}
}

func linkToProfile(mediaID uuid.UUID, mediaType string, profileID uuid.UUID) error {
	entry := models.LibraryEntry{
		ProfileID: profileID,
		MediaID:   mediaID,
		MediaType: mediaType,
	}
	// Use Clauses to ignore duplicates
	result := db.DB.Where("profile_id = ? AND media_id = ?", profileID, mediaID).FirstOrCreate(&entry)
	return result.Error
}

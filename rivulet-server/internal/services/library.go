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
	mediaID, err := EnsureMedia(mdbClient, tmdbClient, mdbApiKey, tmdbApiKey, externalID, mediaType, profileID)
	if err != nil {
		return err
	}
	return linkToProfile(mediaID, mediaType, profileID)
}

// EnsureMedia checks if media exists for profile, if not fetches and creates it. Returns MediaID.
func EnsureMedia(mdbClient *mdblist.Client, tmdbClient *tmdb.Client, mdbApiKey, tmdbApiKey, externalID, mediaType string, profileID uuid.UUID) (uuid.UUID, error) {
	// 1. Determine Type and ID
	cleanID := externalID
	if strings.Contains(externalID, ":") {
		parts := strings.Split(externalID, ":")
		cleanID = parts[1]
	}

	// 2. Check if already exists in DB for this PROFILE
	var existingMovie models.Movie
	var existingSeries models.Series

	if mediaType == "movie" {
		if err := db.DB.Where("(external_ids ->> 'imdb' = ? OR external_ids ->> 'tmdb' = ?) AND profile_id = ?", cleanID, cleanID, profileID).First(&existingMovie).Error; err == nil {
			return existingMovie.ID, nil
		}
	} else {
		if err := db.DB.Where("(external_ids ->> 'imdb' = ? OR external_ids ->> 'tmdb' = ?) AND profile_id = ?", cleanID, cleanID, profileID).First(&existingSeries).Error; err == nil {
			return existingSeries.ID, nil
		}
	}

	// 3. Fetch from MDBList
	details, err := mdbClient.GetDetails(mdbApiKey, cleanID, mediaType)
	if err != nil {
		return uuid.Nil, fmt.Errorf("metadata not found: %v", err)
	}

	// 4. Download Images
	posterPath, _ := DownloadImage(details.Poster)
	backdropPath, _ := DownloadImage(details.Backdrop)

	var logoPath string
	if details.TmdbID != 0 {
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
			ProfileID:      profileID,
			Title:          details.Title,
			Overview:       details.Description,
			MetadataSource: "mdblist",
			ExternalIDs:    map[string]any{"imdb": details.ImdbID, "tmdb": details.TmdbID},
		}

		err = db.DB.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&movie).Error; err != nil {
				return err
			}
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
			return uuid.Nil, err
		}
		return movie.ID, nil

	} else {
		// Series
		series := models.Series{
			ProfileID:   profileID,
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
					return err // Warn?
				}
				for _, s := range tmdbShow.Seasons {
					var seasonPosterPath string
					if s.PosterPath != "" {
						fullUrl := "https://image.tmdb.org/t/p/w500" + s.PosterPath
						seasonPosterPath, _ = DownloadImage(fullUrl)
					}
					season := models.Season{
						SeriesID:     series.ID,
						SeasonNumber: s.SeasonNumber,
						Title:        s.Name,
						Overview:     s.Overview,
						ExternalIDs:  map[string]any{"tmdb": s.ID},
					}
					if err := tx.Create(&season).Error; err != nil {
						continue
					}
					if seasonPosterPath != "" {
						tx.Create(&models.Image{OwnerType: "Season", OwnerID: season.ID, Type: "poster", LocalPath: seasonPosterPath})
					}
				}
			}
			return nil
		})
		if err != nil {
			return uuid.Nil, err
		}
		return series.ID, nil
	}
}

// EnsureEpisode ensures an episode exists for the given series and identifiers.
// Since EnsureMedia creates Seasons, this checks for the Episode record and fetches from TMDB if missing.
func EnsureEpisode(tmdbClient *tmdb.Client, tmdbApiKey string, seriesID uuid.UUID, seasonNum, episodeNum int) (uuid.UUID, error) {
	// 1. Find Season
	var season models.Season
	if err := db.DB.Where("series_id = ? AND season_number = ?", seriesID, seasonNum).First(&season).Error; err != nil {
		// Season missing? EnsureMedia should have created it if it exists on TMDB.
		// If it's a new season not in DB, we might need to fetch season details?
		// For now simple fail.
		return uuid.Nil, fmt.Errorf("season %d not found for series", seasonNum)
	}

	// 2. Check Episode
	var episode models.Episode
	if err := db.DB.Where("season_id = ? AND episode_number = ?", season.ID, episodeNum).First(&episode).Error; err == nil {
		return episode.ID, nil
	}

	// 3. Fetch from TMDB
	// Need TMDB ID of the Series to call API.
	var series models.Series
	if err := db.DB.First(&series, seriesID).Error; err != nil {
		return uuid.Nil, err
	}

	tmdbIDVal, ok := series.ExternalIDs["tmdb"]
	if !ok {
		return uuid.Nil, fmt.Errorf("series has no tmdb id")
	}

	// Handle float64/int weirdness from JSON
	var tmdbID int
	if f, ok := tmdbIDVal.(float64); ok {
		tmdbID = int(f)
	} else if i, ok := tmdbIDVal.(int); ok {
		tmdbID = i
	} else {
		return uuid.Nil, fmt.Errorf("invalid tmdb id format")
	}

	epDetails, err := tmdbClient.GetEpisodeDetails(tmdbApiKey, tmdbID, seasonNum, episodeNum)
	if err != nil {
		return uuid.Nil, err
	}

	// 4. Create Episode
	newEp := models.Episode{
		SeasonID:      season.ID,
		Title:         epDetails.Name,
		Overview:      epDetails.Overview,
		EpisodeNumber: epDetails.EpisodeNumber,
		Runtime:       epDetails.Runtime,
		AirDate:       nil, // Parse if needed
		ExternalIDs:   map[string]any{"tmdb": epDetails.ID},
	}
	if epDetails.AirDate != "" {
		// simple parse attempts? skip for now
	}

	err = db.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&newEp).Error; err != nil {
			return err
		}

		// Image
		if epDetails.StillPath != "" {
			fullUrl := "https://image.tmdb.org/t/p/w500" + epDetails.StillPath
			path, _ := DownloadImage(fullUrl)
			if path != "" {
				tx.Create(&models.Image{OwnerType: "Episode", OwnerID: newEp.ID, Type: "still", LocalPath: path})
			}
		}
		return nil
	})

	if err != nil {
		return uuid.Nil, err
	}

	return newEp.ID, nil
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

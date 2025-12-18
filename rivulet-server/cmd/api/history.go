package api

import (
	"fmt"
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// POST /history/progress
func UpdateProgress(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)

	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	// Retrieve API Keys for EnsureMedia
	keys, err := getUserKeys(userID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "user not found"})
	}
	// Note: We proceed even if keys missing? EnsureMedia requires them.
	// If API keys missing, we can't fetch metadata for NEW items.

	type ProgressRequest struct {
		ImdbID  string `json:"imdb_id"`
		Type    string `json:"type"` // "movie" or "tv"
		Season  int    `json:"season"`
		Episode int    `json:"episode"`

		PositionTicks int64 `json:"position_ticks"`
		DurationTicks int64 `json:"duration_ticks"`
		IsWatched     bool  `json:"is_watched"`
		Timestamp     int64 `json:"timestamp"`
	}

	var batch []ProgressRequest
	if err := c.Bind(&batch); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	if len(batch) == 0 {
		return c.JSON(http.StatusOK, map[string]string{"status": "empty batch"})
	}

	err = db.DB.Transaction(func(tx *gorm.DB) error {
		for _, item := range batch {
			clientTime := time.Unix(item.Timestamp, 0)

			if item.ImdbID == "" {
				continue
			}

			mediaType := item.Type
			if mediaType == "tv" {
				mediaType = "series"
			}

			// 3. Upsert Progress
			var progress models.MediaProgress

			// Find existing by keys
			query := tx.Where("profile_id = ? AND imdb_id = ? AND type = ? AND season_number = ? AND episode_number = ?",
				profile.ID, item.ImdbID, mediaType, item.Season, item.Episode)

			result := query.First(&progress)

			if result.Error == nil {
				if clientTime.Before(progress.LastPlayedAt) {
					continue
				}
			}

			progress.ProfileID = profile.ID
			progress.ImdbID = item.ImdbID
			progress.Type = mediaType
			progress.SeasonNumber = item.Season
			progress.EpisodeNumber = item.Episode

			progress.PositionTicks = item.PositionTicks
			progress.DurationTicks = item.DurationTicks
			progress.IsWatched = item.IsWatched
			if item.IsWatched {
				progress.PositionTicks = 0
				progress.DurationTicks = 0
			}
			progress.LastPlayedAt = clientTime

			// 4. Resolve Next Episode (Backend Driven)
			progress.NextSeasonNumber = nil
			progress.NextEpisodeNumber = nil

			if item.Type != "movie" {
				// User-requested logic: Direct API Lookup (No Local DB for resolving next episode)

				// 1. Resolve IMDB ID -> TMDB ID via MDBList
				// We need TMDB ID to query TMDB season/episode APIs
				details, err := MdbClient.GetDetails(keys.MDBList, item.ImdbID, "show")
				if err == nil && details.TmdbID != 0 {
					tmdbID := details.TmdbID

					// 2. Check Next Episode in Current Season (S, E+1)
					// Verify via TMDB API directly
					nextS := item.Season
					nextE := item.Episode + 1

					// We check if it exists by trying to fetch details
					data, err := TmdbClient.GetEpisodeDetails(keys.TMDB, tmdbID, nextS, nextE)
					if err == nil && data != nil && data.ID != 0 {
						println("Next episode exists: S" + strconv.Itoa(nextS) + "E" + strconv.Itoa(nextE))
						progress.NextSeasonNumber = &nextS
						progress.NextEpisodeNumber = &nextE
					} else {
						println("Next episode does not exist: S" + strconv.Itoa(nextS) + "E" + strconv.Itoa(nextE))
						// 3. Check First Episode of Next Season (S+1, E1)
						nextS = item.Season + 1
						nextE = 1
						data, err := TmdbClient.GetEpisodeDetails(keys.TMDB, tmdbID, nextS, nextE)
						if err == nil && data != nil && data.ID != 0 {
							progress.NextSeasonNumber = &nextS
							progress.NextEpisodeNumber = &nextE
						}
					}
				}
			}

			if err := tx.Clauses(clause.OnConflict{
				Columns:   []clause.Column{{Name: "id"}},
				UpdateAll: true,
			}).Save(&progress).Error; err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "batch update failed"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "synced"})
}

// Enrich with Media Data
	type HistoryResult struct {
		MediaID       string     `json:"media_id"`             // External ID (tmdb:123 or tt123)
		EpisodeID     *uuid.UUID `json:"episode_id,omitempty"` // Deprecated but maybe useful? No, we removed it.
		Type          string     `json:"type"`                 // "movie" or "episode"
		Title         string     `json:"title"`                // Movie title or "Series - Episode Title"
		PosterPath    string     `json:"poster_path"`
		BackdropPath  string     `json:"backdrop_path"`
		PositionTicks int64      `json:"position_ticks"`
		DurationTicks int64      `json:"duration_ticks"`
		LastPlayedAt  time.Time  `json:"last_played_at"`

		IsWatched bool `json:"is_watched"`

		// Extra for frontend logic
		SeriesName       string  `json:"series_name,omitempty"`
		SeasonNumber     int     `json:"season_number,omitempty"`
		EpisodeNumber    int     `json:"episode_number,omitempty"`
		NextSeason       *int    `json:"next_season,omitempty"`
		NextEpisode      *int    `json:"next_episode,omitempty"`
		NextEpisodeTitle *string `json:"next_episode_title,omitempty"`
	}

// GET /history
// Returns X latest items sorted by LastPlayedAt desc
func GetHistory(c echo.Context, filterSame bool) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	mediaId := c.QueryParam("external_id")
	mediaType := c.QueryParam("type")

	// Need keys for fallback fetching
	// No need for keys as we rely on local metadata populated by UpdateProgress

	limitParam := c.QueryParam("limit")
	limit := 20
	if limitParam != "" {
		if l, err := strconv.Atoi(limitParam); err == nil && l > 0 {
			limit = l
		}
	}

	var allProgress []models.MediaProgress
	// Fetch more items to allow for deduplication by Series
	dbLimit := limit * 5
	if limit > 100 {
		dbLimit = limit + 100
	}

	if mediaId != "" && mediaType != "" {
		if err := db.DB.Where("profile_id = ? AND imdb_id = ? AND type = ?", profile.ID, mediaId, mediaType).
			Order("last_played_at desc").
			Limit(dbLimit).
			Find(&allProgress).Error; err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "db error"})
		}
	} else {
		if err := db.DB.Where("profile_id = ?", profile.ID).
			Order("last_played_at desc").
			Limit(dbLimit).
			Find(&allProgress).Error; err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "db error"})
		}
	}


	// Filter unique Series/Movies
	var progress []models.MediaProgress

	if filterSame {
		seen := make(map[string]bool)
		for _, p := range allProgress {
			if len(progress) >= limit {
				break
			}
			if seen[p.ImdbID] {
				continue
			}
			seen[p.ImdbID] = true
			progress = append(progress, p)
		}
	} else {
		progress = allProgress
	}

	var results []HistoryResult

	for _, p := range progress {
		var res HistoryResult
		// res.EpisodeID = p.EpisodeID // Removed from model
		res.PositionTicks = p.PositionTicks
		res.DurationTicks = p.DurationTicks
		res.LastPlayedAt = p.LastPlayedAt
		res.IsWatched = p.IsWatched
		res.SeasonNumber = p.SeasonNumber
		res.EpisodeNumber = p.EpisodeNumber

		// Next Episode Defaults
		res.NextSeason = p.NextSeasonNumber
		res.NextEpisode = p.NextEpisodeNumber

		// Set Media ID (External Format - IMDB)
		res.MediaID = p.ImdbID
		res.Type = p.Type

		// 1. Try Local DB First
		foundLocal := false
		var tmdbID int // We might need this for API fallback even if local DB lookup fails

		if p.Type == "movie" {
			var movie models.Movie
			if err := db.DB.Where("external_ids ->> 'imdb' = ?", p.ImdbID).First(&movie).Error; err == nil {
				foundLocal = true
				res.Title = movie.Title
				res.PosterPath = getImagePath(movie.ID, "Movie", "poster")
				res.BackdropPath = getImagePath(movie.ID, "Movie", "backdrop")
			}
		} else {
			// Series
			var series models.Series
			if err := db.DB.Where("external_ids ->> 'imdb' = ?", p.ImdbID).First(&series).Error; err == nil {
				foundLocal = true
				res.SeriesName = series.Title
				res.PosterPath = getImagePath(series.ID, "Series", "poster")
				res.BackdropPath = getImagePath(series.ID, "Series", "backdrop")
			}
		}

		keys, err := getUserKeys(userID)
		if err != nil {
			return c.JSON(http.StatusForbidden, map[string]string{"error": "no keys found"})
		}
		details, err := MdbClient.GetDetails(keys.MDBList, p.ImdbID, p.Type)
		if err != nil {
			return c.JSON(http.StatusNotFound, map[string]string{"error": "not found"})
		}
		
		// 2. If Not Found Locally, Use API
		if !foundLocal {
			// Fetch Metadata from MDBList
			// This gives us Title, Poster, Backdrop, and TMDB ID
			res.PosterPath = details.Poster
			res.BackdropPath = details.Backdrop
			if p.Type == "movie" {
				res.Title = details.Title
			} else {
				res.SeriesName = details.Title
			}
		}
		
		tmdbID = details.TmdbID

		// Fetch Episode Title via TMDB
		// We need to fetch the season details
		if p.Type == "show" && tmdbID != 0 {
			// Current Episode
			ep, err := TmdbClient.GetEpisodeDetails(keys.TMDB, tmdbID, p.SeasonNumber, p.EpisodeNumber)
			if err == nil {
				res.Title = ep.Name
			} else {
				res.Title = fmt.Sprintf("S%dE%d", p.SeasonNumber, p.EpisodeNumber)
			}

			// Next Episode Title (if we know the number)
			if p.NextSeasonNumber != nil && p.NextEpisodeNumber != nil {
				nextEp, err := TmdbClient.GetEpisodeDetails(keys.TMDB, tmdbID, *p.NextSeasonNumber, *p.NextEpisodeNumber)
				if err == nil {
					res.NextEpisodeTitle = &nextEp.Name
				}
			}
		}
		results = append(results, res)
	}

	return c.JSON(http.StatusOK, results)
}

func GetProfileHistory(c echo.Context) error {
	return GetHistory(c, true);
}

func GetMediaHistory(c echo.Context) error {
	return GetHistory(c, false);
}

// DELETE /history/:media_id
func DeleteHistory(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	mediaID := c.Param("media_id")
	// mediaID format: "tt123" or "tmdb:123" (legacy?) or UUID

	// We need to resolve to IMDb ID to delete from MediaProgress
	var imdbID string

	if len(mediaID) > 2 && mediaID[:2] == "tt" {
		imdbID = mediaID
	} else if len(mediaID) > 5 && mediaID[:5] == "tmdb:" {
		// Resolve TMDB to IMDb if passed?
		// Try finding by TMDB ID
		tmdbIDPart := mediaID[5:]
		var movie models.Movie
		if err := db.DB.Where("external_ids ->> 'tmdb' = ?", tmdbIDPart).First(&movie).Error; err == nil {
			if id, ok := movie.ExternalIDs["imdb"].(string); ok {
				imdbID = id
			}
		} else {
			var series models.Series
			if err := db.DB.Where("external_ids ->> 'tmdb' = ?", tmdbIDPart).First(&series).Error; err == nil {
				if id, ok := series.ExternalIDs["imdb"].(string); ok {
					imdbID = id
				}
			}
		}
	} else {
		// Try finding movie or series by UUID or exact match
		var movie models.Movie
		if err := db.DB.Where("id::text = ?", mediaID).First(&movie).Error; err == nil {
			if id, ok := movie.ExternalIDs["imdb"].(string); ok {
				imdbID = id
			}
		} else {
			var series models.Series
			if err := db.DB.Where("id::text = ?", mediaID).First(&series).Error; err == nil {
				if id, ok := series.ExternalIDs["imdb"].(string); ok {
					imdbID = id
				}
			}
		}
	}

	if imdbID != "" {
		if err := db.DB.Where("profile_id = ? AND imdb_id = ?", profile.ID, imdbID).Delete(&models.MediaProgress{}).Error; err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "db error"})
		}
	}

	return c.JSON(http.StatusOK, map[string]bool{"success": true})
}

func getImagePath(ownerID uuid.UUID, ownerType, imgType string) string {
	var img models.Image
	if err := db.DB.Where("owner_id = ? AND owner_type = ? AND type = ?", ownerID, ownerType, imgType).First(&img).Error; err == nil {
		return "/images/" + getFileName(img.LocalPath)
	}
	return ""
}

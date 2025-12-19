package api

import (
	"fmt"
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"rivulet_server/internal/providers/mdblist"
	"rivulet_server/internal/providers/tmdb"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

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

type DeleteProgressRequest struct {
	ImdbID  string `json:"imdb_id"`
	Type    string `json:"type"` // "movie" or "show"
	Season  int    `json:"season"`
	Episode int    `json:"episode"`
}

// POST /history/progress
func UpdateProgress(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)

	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
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

			// If the item is not marked as watched, the position is 0 and duration is zero, delete it
			if !item.IsWatched && item.PositionTicks == 0 && item.DurationTicks == 0 {
				var deleteItem DeleteProgressRequest
				deleteItem.ImdbID = item.ImdbID
				deleteItem.Type = item.Type
				deleteItem.Season = item.Season
				deleteItem.Episode = item.Episode
				_deleteProgressItem(deleteItem, tx, profile)
				continue
			}

			// 3. Upsert Progress
			var progress models.MediaProgress

			// Find existing by keys
			query := tx.Where("profile_id = ? AND imdb_id = ? AND type = ? AND season_number = ? AND episode_number = ?",
				profile.ID, item.ImdbID, item.Type, item.Season, item.Episode)

			result := query.First(&progress)

			if result.Error == nil {
				if clientTime.Before(progress.LastPlayedAt) {
					continue
				}
			}

			progress.ProfileID = profile.ID
			progress.ImdbID = item.ImdbID
			progress.Type = item.Type
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

// DELETE /history/progress
func DeleteProgress(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)

	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	var batch []DeleteProgressRequest
	if err := c.Bind(&batch); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	err = db.DB.Transaction(func(tx *gorm.DB) error {
		for _, item := range batch {
			err := _deleteProgressItem(item, tx, profile)
			if err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "batch delete failed"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "synced"})
}

func _deleteProgressItem(item DeleteProgressRequest, tx *gorm.DB, profile models.Profile) error {
	if item.ImdbID == "" {
		return nil
	}

	result := tx.Where("profile_id = ? AND imdb_id = ? AND type = ? AND season_number = ? AND episode_number = ?",
		profile.ID, item.ImdbID, item.Type, item.Season, item.Episode).
		Delete(&models.MediaProgress{})

	return result.Error
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
			Order("season_number desc").
			Order("episode_number desc").
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
	cachedDetails := make(map[string]*mdblist.MediaDetail)
	cachedSeasons := make(map[string]*tmdb.SeasonDetails)

	for _, p := range progress {
		var res HistoryResult
		res.PositionTicks = p.PositionTicks
		res.DurationTicks = p.DurationTicks
		res.LastPlayedAt = p.LastPlayedAt
		res.IsWatched = p.IsWatched
		res.SeasonNumber = p.SeasonNumber
		res.EpisodeNumber = p.EpisodeNumber

		// Set Media ID (External Format - IMDB)
		res.MediaID = p.ImdbID
		res.Type = p.Type

		// 1. Try Local DB First
		foundLocal := false
		var tmdbID int

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
		_, ok := cachedDetails[p.ImdbID]
		if !ok {
			details, err := MdbClient.GetDetails(keys.MDBList, p.ImdbID, p.Type)
			if err != nil {
				return c.JSON(http.StatusNotFound, map[string]string{"error": "not found"})
			}
			cachedDetails[p.ImdbID] = details
		}
		details := cachedDetails[p.ImdbID]

		// 2. If Not Found Locally, Use API
		if !foundLocal {
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
			sId := fmt.Sprintf("%d:%d", tmdbID, p.SeasonNumber)
			_, ok := cachedSeasons[sId]
			if !ok {
				sesason, err := TmdbClient.GetSeasonDetails(keys.TMDB, tmdbID, p.SeasonNumber)
				if err == nil {
					cachedSeasons[sId] = sesason
				}
			}
			// Current Episode
			ep := cachedSeasons[sId].Episodes[p.EpisodeNumber-1]
			res.Title = ep.Name
		}
		results = append(results, res)
	}

	return c.JSON(http.StatusOK, results)
}

func GetProfileHistory(c echo.Context) error {
	return GetHistory(c, true)
}

func GetMediaHistory(c echo.Context) error {
	return GetHistory(c, false)
}

func getImagePath(ownerID uuid.UUID, ownerType, imgType string) string {
	var img models.Image
	if err := db.DB.Where("owner_id = ? AND owner_type = ? AND type = ?", ownerID, ownerType, imgType).First(&img).Error; err == nil {
		return "/images/" + getFileName(img.LocalPath)
	}
	return ""
}

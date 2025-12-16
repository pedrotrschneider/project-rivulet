package api

import (
	"fmt"
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"rivulet_server/internal/services"
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
		ExternalID string `json:"external_id"` // "tt123", "tmdb:123"
		Type       string `json:"type"`        // "movie" or "tv"
		Season     int    `json:"season"`
		Episode    int    `json:"episode"`

		PositionTicks int64  `json:"position_ticks"`
		DurationTicks int64  `json:"duration_ticks"`
		IsWatched     bool   `json:"is_watched"`
		Timestamp     int64  `json:"timestamp"`
		Magnet        string `json:"magnet"`
		FileIndex     *int   `json:"file_index"`
		NextSeason    *int   `json:"next_season"`
		NextEpisode   *int   `json:"next_episode"`
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

			// 1. Ensure Media Exists (Movie or Series)
			// Helper from services requires Clients
			// We can import services but `getUserKeys` is local in library.go.
			// `MdbClient` and `TmdbClient` are globals in api package?
			// Yes, used in AddToLibrary (exported or local in library.go?).
			// AddToLibrary line 63 uses `MdbClient`.
			// So `MdbClient` and `TmdbClient` are available here.

			// standardize type
			mediaType := item.Type
			if mediaType == "tv" {
				mediaType = "series"
			} // DB uses "series"?
			// DB models are Movie / Series. EnsureMedia expects "movie" or "series" or "tv"?
			// EnsureMedia line 21: if mediaType == "movie". Else Series.
			// Pass "movie" or "tv" generally works if backend handles it.
			// Re-checking EnsureMedia: It handles "movie" vs else.
			// But for Series creation, it sets MediaType to passed value? No, LibraryEntry uses passed value.
			// EnsureMedia doesn't use mediaType for creation other than selecting code path.

			mediaID, err := services.EnsureMedia(MdbClient, TmdbClient, keys.MDBList, keys.TMDB, item.ExternalID, item.Type, profile.ID)
			if err != nil {
				// Log and continue? specific failure shouldn't block entire batch?
				fmt.Println("Error ensuring media:", err)
				continue
			}

			// 2. Ensure Episode if TV
			var episodeID *uuid.UUID
			if item.Type != "movie" {
				epID, err := services.EnsureEpisode(TmdbClient, keys.TMDB, mediaID, item.Season, item.Episode)
				if err == nil {
					episodeID = &epID
				} else {
					fmt.Println("Error ensuring episode:", err)
					// Verify what to do: Create progress without episode ID?
					// Model: EpisodeID is nullable. But for Series, having Null EpisodeID usually means "Series Progress" (e.g. at show level).
					// If we are tracking Episode Progress, we really need the ID.
					// If fail, maybe skip?
					continue
				}
			}

			// 3. Upsert Progress
			var progress models.MediaProgress

			query := tx.Where("profile_id = ? AND media_id = ?", profile.ID, mediaID)
			if episodeID != nil {
				query = query.Where("episode_id = ?", episodeID)
			} else {
				query = query.Where("episode_id IS NULL")
			}

			result := query.First(&progress)

			if result.Error == nil {
				if clientTime.Before(progress.LastPlayedAt) {
					continue
				}
			}

			progress.ProfileID = profile.ID
			progress.MediaID = &mediaID
			progress.EpisodeID = episodeID
			progress.PositionTicks = item.PositionTicks
			progress.DurationTicks = item.DurationTicks
			progress.IsWatched = item.IsWatched
			if item.IsWatched {
				progress.PositionTicks = 0
				progress.DurationTicks = 0
			}
			progress.LastPlayedAt = clientTime
			if item.Magnet != "" {
				progress.LastMagnet = item.Magnet
			}
			if item.FileIndex != nil {
				progress.LastFileIndex = item.FileIndex
			}
			if item.NextSeason != nil {
				progress.NextSeason = item.NextSeason
			}
			if item.NextEpisode != nil {
				progress.NextEpisode = item.NextEpisode
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

// GET /history
// Returns X latest items sorted by LastPlayedAt desc
func GetHistory(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	// Need keys for fallback fetching
	keys, err := getUserKeys(userID)
	if err != nil {
		// If no keys, we can't fetch remote, but can still return local if available
		// Log or suppress? Proceed.
	}

	limitParam := c.QueryParam("limit")
	limit := 20
	if limitParam != "" {
		if l, err := strconv.Atoi(limitParam); err == nil && l > 0 {
			limit = l
		}
	}

	var allProgress []models.MediaProgress
	// Fetch more items than limit to allow for deduplication
	// e.g. fetch 5x limit to skip over multiple episodes of same show
	dbLimit := limit * 5
	if limit > 100 {
		dbLimit = limit + 100 // Cap the multiplier for large requests
	}

	if err := db.DB.Where("profile_id = ?", profile.ID).
		Order("last_played_at desc").
		Limit(dbLimit).
		Find(&allProgress).Error; err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "db error"})
	}

	// Filter unique MediaID (Series/Movie)
	var progress []models.MediaProgress
	seen := make(map[string]bool)
	for _, p := range allProgress {
		if len(progress) >= limit {
			break
		}
		// MediaID is the Series ID or Movie ID
		mid := p.MediaID.String()
		if seen[mid] {
			continue
		}
		seen[mid] = true
		progress = append(progress, p)
	}

	// Enrich with Media Data
	type HistoryResult struct {
		MediaID       string     `json:"media_id"`             // Changed to string for External ID
		EpisodeID     *uuid.UUID `json:"episode_id,omitempty"` // Internal is fine for tracking, but navigation needs external context? Frontend uses media_id (series/movie).
		Type          string     `json:"type"`                 // "movie" or "episode"
		Title         string     `json:"title"`                // Movie title or "Series - Episode Title"
		PosterPath    string     `json:"poster_path"`
		BackdropPath  string     `json:"backdrop_path"`
		PositionTicks int64      `json:"position_ticks"`
		DurationTicks int64      `json:"duration_ticks"`
		LastPlayedAt  time.Time  `json:"last_played_at"`
		LastMagnet    string     `json:"last_magnet"`
		LastFileIndex *int       `json:"last_file_index"`
		IsWatched     bool       `json:"is_watched"`

		// Extra for frontend logic
		SeriesName    string `json:"series_name,omitempty"`
		SeasonNumber  int    `json:"season_number,omitempty"`
		EpisodeNumber int    `json:"episode_number,omitempty"`
		NextSeason    *int   `json:"next_season,omitempty"`
		NextEpisode   *int   `json:"next_episode,omitempty"`
	}

	var results []HistoryResult

	for _, p := range progress {
		var res HistoryResult
		res.EpisodeID = p.EpisodeID
		res.PositionTicks = p.PositionTicks
		res.DurationTicks = p.DurationTicks
		res.LastPlayedAt = p.LastPlayedAt
		res.LastMagnet = p.LastMagnet
		res.LastFileIndex = p.LastFileIndex
		res.IsWatched = p.IsWatched
		res.NextSeason = p.NextSeason
		res.NextEpisode = p.NextEpisode

		// Check Library Status
		var inLibrary bool
		var libEntry models.LibraryEntry
		if err := db.DB.Where("profile_id = ? AND media_id = ?", profile.ID, p.MediaID).First(&libEntry).Error; err == nil {
			inLibrary = true
		}

		if p.EpisodeID != nil {
			// Series Episode
			res.Type = "episode"
			var series models.Series
			var episode models.Episode
			var season models.Season

			// Get Series
			if err := db.DB.First(&series, p.MediaID).Error; err == nil {
				res.SeriesName = series.Title

				// Resolve External ID (prefer TMDB for ease, or IMDb)
				if val, ok := series.ExternalIDs["tmdb"]; ok {
					res.MediaID = fmt.Sprintf("%v", val)
				} else if val, ok := series.ExternalIDs["imdb"]; ok {
					res.MediaID = fmt.Sprintf("%v", val)
				} else {
					res.MediaID = series.ID.String() // Fallback
				}

				if inLibrary {
					res.PosterPath = getImagePath(series.ID, "Series", "poster")
					res.BackdropPath = getImagePath(series.ID, "Series", "backdrop")
				} else {
					// Fetch Remote
					// We need TMDB ID
					if tmdbID, ok := getTmdbID(series.ExternalIDs); ok && keys.TMDB != "" {
						show, err := TmdbClient.GetTVShowDetails(keys.TMDB, tmdbID)
						if err == nil {
							if show.PosterPath != "" {
								res.PosterPath = "https://image.tmdb.org/t/p/w500" + show.PosterPath
							}
							if show.BackdropPath != "" {
								res.BackdropPath = "https://image.tmdb.org/t/p/w500" + show.BackdropPath
							}
						}
					}
				}
			}

			// Get Episode & Season
			if err := db.DB.First(&episode, p.EpisodeID).Error; err == nil {
				res.Title = episode.Title
				res.EpisodeNumber = episode.EpisodeNumber

				if err := db.DB.First(&season, episode.SeasonID).Error; err == nil {
					res.SeasonNumber = season.SeasonNumber
				}
			}
		} else {
			// Movie
			res.Type = "movie"
			var movie models.Movie
			if err := db.DB.First(&movie, p.MediaID).Error; err == nil {
				res.Title = movie.Title

				// External ID
				if val, ok := movie.ExternalIDs["tmdb"]; ok {
					res.MediaID = fmt.Sprintf("%v", val)
				} else if val, ok := movie.ExternalIDs["imdb"]; ok {
					res.MediaID = fmt.Sprintf("%v", val)
				} else {
					res.MediaID = movie.ID.String()
				}

				if inLibrary {
					res.PosterPath = getImagePath(movie.ID, "Movie", "poster")
					res.BackdropPath = getImagePath(movie.ID, "Movie", "backdrop")
				} else {
					// Fetch Remote
					if tmdbID, ok := getTmdbID(movie.ExternalIDs); ok && keys.TMDB != "" {
						// MDBList preference
						foundMdb := false
						if keys.MDBList != "" {
							details, err := MdbClient.GetDetails(keys.MDBList, fmt.Sprintf("tmdb:%d", tmdbID), "movie")
							if err == nil {
								res.PosterPath = details.Poster
								res.BackdropPath = details.Backdrop
								foundMdb = true
							}
						}

						// Fallback to TMDB directly if MDBList failed or key missing
						if !foundMdb {
							details, err := TmdbClient.GetMovieDetails(keys.TMDB, tmdbID)
							if err == nil {
								if details.PosterPath != "" {
									res.PosterPath = "https://image.tmdb.org/t/p/w500" + details.PosterPath
								}
								if details.BackdropPath != "" {
									res.BackdropPath = "https://image.tmdb.org/t/p/w500" + details.BackdropPath
								}
							}
						}
					} else if imdbID, ok := movie.ExternalIDs["imdb"].(string); ok && keys.MDBList != "" {
						details, err := MdbClient.GetDetails(keys.MDBList, imdbID, "movie")
						if err == nil {
							res.PosterPath = details.Poster
							res.BackdropPath = details.Backdrop
						}
					}
				}
			}
		}

		results = append(results, res)
	}

	return c.JSON(http.StatusOK, results)
}

func getTmdbID(ids map[string]any) (int, bool) {
	val, ok := ids["tmdb"]
	if !ok {
		return 0, false
	}
	if f, ok := val.(float64); ok {
		return int(f), true
	}
	if i, ok := val.(int); ok {
		return i, true
	}
	return 0, false
}

// DELETE /history/:media_id
func DeleteHistory(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	mediaID := c.Param("media_id")

	// Delete all progress for this media (Series or Movie)
	// If it is a series, we might want to delete all episodes progress?
	// The param is likely the UUID of the Movie or Series.
	// Our Model `MediaID` stores exactly that.

	if err := db.DB.Where("profile_id = ? AND media_id = ?", profile.ID, mediaID).Delete(&models.MediaProgress{}).Error; err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "db error"})
	}

	return c.JSON(http.StatusOK, map[string]bool{"success": true})
}

func GetMediaHistory(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	externalID := c.QueryParam("external_id")
	mediaType := c.QueryParam("type") // "movie" or "tv"/"series"

	if externalID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "missing external_id"})
	}

	var mediaID uuid.UUID
	found := false

	// Find the Internal Media ID
	if mediaType == "movie" {
		var movie models.Movie
		// Postgres JSONB query
		if err := db.DB.Where("profile_id = ? AND external_ids ->> 'tmdb' = ?", profile.ID, externalID).First(&movie).Error; err == nil {
			mediaID = movie.ID
			found = true
		}
	} else {
		var series models.Series
		if err := db.DB.Where("profile_id = ? AND external_ids ->> 'tmdb' = ?", profile.ID, externalID).First(&series).Error; err == nil {
			mediaID = series.ID
			found = true
		}
	}

	if !found {
		return c.JSON(http.StatusOK, []interface{}{})
	}

	var progress []models.MediaProgress
	if err := db.DB.Where("profile_id = ? AND media_id = ?", profile.ID, mediaID).
		Order("last_played_at desc").
		Find(&progress).Error; err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "db error"})
	}

	// Map to simplified result or reusable struct
	// Reusing HistoryResult structure but without the complex enrichment/deduplication
	// We mainly need EpisodeID, Season/Episode numbers, Watched status, Position.

	type SimpleHistory struct {
		MediaID       string     `json:"media_id"`
		EpisodeID     *uuid.UUID `json:"episode_id,omitempty"`
		SeasonNumber  int        `json:"season_number,omitempty"`
		EpisodeNumber int        `json:"episode_number,omitempty"`
		PositionTicks int64      `json:"position_ticks"`
		DurationTicks int64      `json:"duration_ticks"`
		IsWatched     bool       `json:"is_watched"`
		LastPlayedAt  time.Time  `json:"last_played_at"`
		LastMagnet    string     `json:"last_magnet"`
		LastFileIndex *int       `json:"last_file_index"`
		NextSeason    *int       `json:"next_season"`
		NextEpisode   *int       `json:"next_episode"`
	}

	var results []SimpleHistory
	for _, p := range progress {
		var s SimpleHistory
		if p.MediaID != nil {
			s.MediaID = p.MediaID.String()
		}
		s.EpisodeID = p.EpisodeID
		s.PositionTicks = p.PositionTicks
		s.DurationTicks = p.DurationTicks
		s.IsWatched = p.IsWatched
		s.LastPlayedAt = p.LastPlayedAt
		s.LastMagnet = p.LastMagnet
		s.LastMagnet = p.LastMagnet
		s.LastFileIndex = p.LastFileIndex
		s.NextSeason = p.NextSeason
		s.NextEpisode = p.NextEpisode

		if p.EpisodeID != nil {
			var ep models.Episode
			if err := db.DB.Select("season_id, episode_number").First(&ep, p.EpisodeID).Error; err == nil {
				s.EpisodeNumber = ep.EpisodeNumber
				var sea models.Season
				if err := db.DB.Select("season_number").First(&sea, ep.SeasonID).Error; err == nil {
					s.SeasonNumber = sea.SeasonNumber
				}
			}
		}
		results = append(results, s)
	}

	return c.JSON(http.StatusOK, results)
}

func getImagePath(ownerID uuid.UUID, ownerType, imgType string) string {
	var img models.Image
	if err := db.DB.Where("owner_id = ? AND owner_type = ? AND type = ?", ownerID, ownerType, imgType).First(&img).Error; err == nil {
		return "/images/" + getFileName(img.LocalPath)
	}
	return ""
}

package api

import (
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type ProgressItem struct {
	MediaID       *uuid.UUID  `json:"media_id"`
	EpisodeID     *uuid.UUID `json:"episode_id"` // Nullable for movies
	PositionTicks int64      `json:"position_ticks"`
	DurationTicks int64      `json:"duration_ticks"`
	IsWatched     bool       `json:"is_watched"`
	Timestamp     int64      `json:"timestamp"` // Unix Epoch from Client
}

// POST /history/progress
func UpdateProgress(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	
	// 1. Get Active Profile
	// Reuse the helper from library.go (make sure it's exported or in a shared package)
	// For now, we'll assume the same logic: check header or default.
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	var batch []ProgressItem
	if err := c.Bind(&batch); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	if len(batch) == 0 {
		return c.JSON(http.StatusOK, map[string]string{"status": "empty batch"})
	}

	// 2. Process Batch Transaction
	err = db.DB.Transaction(func(tx *gorm.DB) error {
		for _, item := range batch {
			clientTime := time.Unix(item.Timestamp, 0)

			// Logic: "Upsert" based on Profile + Media/Episode
			// We only update if the new timestamp is newer than what we have.
			
			// Try to find existing record
			var progress models.MediaProgress
			
			query := tx.Where("profile_id = ? AND media_id = ?", profile.ID, item.MediaID)
			if item.EpisodeID != nil {
				query = query.Where("episode_id = ?", item.EpisodeID)
			} else {
				query = query.Where("episode_id IS NULL")
			}

			result := query.First(&progress)

			if result.Error == nil {
				// Record exists: Check timestamp conflict
				if clientTime.Before(progress.LastPlayedAt) {
					// Client data is older than server data. Ignore this update.
					continue
				}
			}

			// Update fields
			progress.ProfileID = profile.ID
			progress.MediaID = item.MediaID
			progress.EpisodeID = item.EpisodeID
			progress.PositionTicks = item.PositionTicks
			progress.DurationTicks = item.DurationTicks
			progress.IsWatched = item.IsWatched
			progress.LastPlayedAt = clientTime

			// Save (Upsert)
			if err := tx.Clauses(clause.OnConflict{
				Columns:   []clause.Column{{Name: "id"}}, // Update existing by PK
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
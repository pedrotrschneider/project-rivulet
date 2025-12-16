package api

import (
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// POST /favorites
func AddFavorite(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	type Request struct {
		MediaID string `json:"media_id"`
		Hash    string `json:"hash"`
	}
	var req Request
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request"})
	}

	fav := models.FavoriteTorrent{
		ProfileID: profile.ID,
		MediaID:   req.MediaID,
		Hash:      req.Hash,
	}

	// Create if not exists
	result := db.DB.FirstOrCreate(&fav, models.FavoriteTorrent{
		ProfileID: profile.ID,
		MediaID:   req.MediaID,
		Hash:      req.Hash,
	})

	if result.Error != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": result.Error.Error()})
	}

	return c.JSON(http.StatusOK, map[string]bool{"success": true})
}

// DELETE /favorites
func RemoveFavorite(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	type Request struct {
		MediaID string `json:"media_id"`
		Hash    string `json:"hash"`
	}
	var req Request
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request"})
	}

	result := db.DB.Where("profile_id = ? AND media_id = ? AND hash = ?", profile.ID, req.MediaID, req.Hash).Delete(&models.FavoriteTorrent{})
	if result.Error != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": result.Error.Error()})
	}

	return c.JSON(http.StatusOK, map[string]bool{"success": true})
}

// POST /favorites/check
func CheckFavorites(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	type Request struct {
		MediaID string   `json:"media_id"`
		Hashes  []string `json:"hashes"`
	}
	var req Request
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request"})
	}

	if len(req.Hashes) == 0 {
		return c.JSON(http.StatusOK, []string{})
	}

	var foundHashes []string
	db.DB.Model(&models.FavoriteTorrent{}).
		Where("profile_id = ? AND media_id = ? AND hash IN ?", profile.ID, req.MediaID, req.Hashes).
		Pluck("hash", &foundHashes)

	return c.JSON(http.StatusOK, foundHashes)
}

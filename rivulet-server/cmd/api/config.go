package api

import (
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

type ConfigRequest struct {
	RealDebridKey string `json:"real_debrid_key"`
	TMDbKey       string `json:"tmdb_key"`
	MDBListKey    string `json:"mdblist_key"`
}

// POST /user/config
func UpdateUserConfig(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)

	var req ConfigRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	// Fetch Account
	var account models.Account
	if err := db.DB.First(&account, userID).Error; err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "user not found"})
	}

	// Update fields if provided (allow partial updates)
	if req.RealDebridKey != "" {
		account.RealDebridKey = req.RealDebridKey
	}
	if req.TMDbKey != "" {
		account.TMDbKey = req.TMDbKey
	}
	if req.MDBListKey != "" {
		account.MDBListKey = req.MDBListKey
	}

	if err := db.DB.Save(&account).Error; err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to save config"})
	}

	return c.JSON(http.StatusOK, map[string]string{"status": "updated"})
}

// GET /user/config
// Returns current keys (masked for security)
func GetUserConfig(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	var account models.Account
	db.DB.Select("real_debrid_key, tm_db_key, mdb_list_key").First(&account, userID)

	return c.JSON(http.StatusOK, map[string]string{
		"real_debrid_key": maskKey(account.RealDebridKey),
		"tmdb_key":        maskKey(account.TMDbKey),
		"mdblist_key":     maskKey(account.MDBListKey),
	})
}

func maskKey(key string) string {
	if len(key) < 4 {
		return "****"
	}
	return key[:4] + "****"
}
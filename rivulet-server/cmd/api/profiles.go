package api

import (
	"fmt"
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// GET /profiles
func ListProfiles(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)

	var profiles []models.Profile
	if err := db.DB.Where("account_id = ?", userID).Find(&profiles).Error; err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "db error"})
	}

	return c.JSON(http.StatusOK, profiles)
}

// POST /profiles
func CreateProfile(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)

	var req struct {
		Name   string `json:"name"`
		Avatar string `json:"avatar"`
	}
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	if req.Name == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "name is required"})
	}

	// Use a default avatar if none provided
	if req.Avatar == "" {
		req.Avatar = fmt.Sprintf("https://api.dicebear.com/7.x/bottts/svg?seed=%s", req.Name)
	}

	profile := models.Profile{
		AccountID: userID,
		Name:      req.Name,
		Avatar:    req.Avatar,
	}

	if err := db.DB.Create(&profile).Error; err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to create profile"})
	}

	return c.JSON(http.StatusCreated, profile)
}
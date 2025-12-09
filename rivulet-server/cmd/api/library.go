package api

import (
	"fmt"
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"rivulet_server/internal/services"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// Helper to get the active profile ID
func getActiveProfile(c echo.Context, accountID uuid.UUID) (models.Profile, error) {
	var profile models.Profile
	
	// 1. Check Header
	headerID := c.Request().Header.Get("X-Profile-ID")
	if headerID != "" {
		if err := db.DB.Where("id = ? AND account_id = ?", headerID, accountID).First(&profile).Error; err == nil {
			return profile, nil
		}
	}

	// 2. Fallback to First Found
	if err := db.DB.Where("account_id = ?", accountID).First(&profile).Error; err != nil {
		return profile, fmt.Errorf("no profiles found")
	}
	return profile, nil
}

// POST /library
func AddToLibrary(c echo.Context) error {
	// 1. Get Inputs
	mdbApiKey := c.Request().Header.Get("X-MDBList-Key") // Or use server config
	tmdbApiKey := c.Request().Header.Get("X-TMDB-Key")
	userID := c.Get("user_id").(uuid.UUID)
	
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	var req struct {
		ExternalID string `json:"external_id"`
		MediaType  string `json:"media_type"`
	}

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	err = services.AddToLibrary(MdbClient, TmdbClient, mdbApiKey, tmdbApiKey, req.ExternalID, req.MediaType, profile.ID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusCreated, map[string]bool{"success": true})
}

// GET /library
// Supports: ?page=1&type=movie&sort=title&order=asc&q=search
func GetLibrary(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	// Params
	page := 1 // Fetch from query param in prod
	limit := 50
	mediaType := c.QueryParam("type") // "movie" or "show"
	// query := c.QueryParam("q")

	var entries []models.LibraryEntry
	
	// Build Query
	tx := db.DB.Where("profile_id = ?", profile.ID)

	if mediaType != "" {
		tx = tx.Where("media_type = ?", mediaType)
	}

	// Pagination
	offset := (page - 1) * limit
	tx = tx.Offset(offset).Limit(limit).Order("created_at desc")

	// Execute
	if err := tx.Find(&entries).Error; err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "db error"})
	}

	// Enhance Response

	type SeasonInfo struct {
		SeasonNumber int    `json:"season_number"`
		Title        string `json:"title"`
		Poster       string `json:"poster_url"`
	}

	type ResponseItem struct {
		UUID      uuid.UUID `json:"uuid"`
		Title     string    `json:"title"`
		Poster    string    `json:"poster_url"`
		Backdrop  string    `json:"backdrop_url"`
		Logo      string    `json:"logo_url"`
		Type      string    `json:"type"`
		AddedAt   string    `json:"added_at"`
		Seasons   []SeasonInfo `json:"seasons,omitempty"`
	}

	var response []ResponseItem
	for _, e := range entries {
		var title string
		
		var seasonsInfo []SeasonInfo

		if e.MediaType == "movie" {
			var m models.Movie
			if err := db.DB.Select("title").First(&m, e.MediaID).Error; err == nil {
				title = m.Title
			}
		} else {
			// Is Series
			var s models.Series
			if err := db.DB.Select("title").First(&s, e.MediaID).Error; err == nil {
				title = s.Title
			}

			var dbSeasons []models.Season
			if err := db.DB.Where("series_id = ?", e.MediaID).Order("season_number asc").Find(&dbSeasons).Error; err == nil {
				
				// 1. Collect Season IDs to fetch images in one batch
				var seasonIDs []uuid.UUID
				for _, sea := range dbSeasons {
					seasonIDs = append(seasonIDs, sea.ID)
				}

				// 2. Fetch Images for these IDs
				var seasonImages []models.Image
				if len(seasonIDs) > 0 {
					// We query all "poster" images belonging to these Season IDs
					db.DB.Where("owner_id IN ? AND type = ?", seasonIDs, "poster").Find(&seasonImages)
				}

				// 3. Create Lookup Map (ID -> Path)
				posterMap := make(map[uuid.UUID]string)
				for _, img := range seasonImages {
					posterMap[img.OwnerID] = img.LocalPath
				}

				// 4. Build Info using the Map
				for _, sea := range dbSeasons {
					seasonsInfo = append(seasonsInfo, SeasonInfo{
						SeasonNumber: sea.SeasonNumber,
						Title:        sea.Title,
						Poster:       posterMap[sea.ID],
					})
				}
			}
		}

		// 2. Fetch Images Explicitly
		var poster, backdrop, logo string
		
		// We fetch all images for this media at once to save queries
		var images []models.Image
		if err := db.DB.Where("owner_id = ?", e.MediaID).Find(&images).Error; err == nil {
			for _, img := range images {
				switch img.Type {
				case "poster":
					poster = img.LocalPath
				case "backdrop":
					backdrop = img.LocalPath
				case "logo":
					logo = img.LocalPath
				}
			}
		}

		response = append(response, ResponseItem{
			UUID:     e.MediaID,
			Title:    title,
			Poster:   poster,
			Backdrop: backdrop,
			Logo:     logo,
			Type:     e.MediaType,
			AddedAt:  e.CreatedAt.Format(time.RFC3339),
			Seasons:  seasonsInfo,
		})
	}

	return c.JSON(http.StatusOK, map[string]any{
		"data": response,
		"meta": map[string]int{"page": page},
	})
}

// GET /library/check/:external_id
func CheckLibrary(c echo.Context) error {
	// id := c.Param("id")
	// Logic: Search DB for Movie/Series with this external ID
	// Then check if it exists in LibraryEntry for current profile
	// Return { in_library: true/false }
	
	// Mock implementation for now
	return c.JSON(http.StatusOK, map[string]bool{"in_library": false})
}
package api

import (
	"fmt"
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"rivulet_server/internal/services"
	"strings"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

// Helper to get the active profile ID from X-Profile-ID header
func getActiveProfile(c echo.Context, accountID uuid.UUID) (models.Profile, error) {
	var profile models.Profile

	// Get Profile ID from header (required)
	headerID := c.Request().Header.Get("X-Profile-ID")
	if headerID == "" {
		return profile, fmt.Errorf("X-Profile-ID header is required")
	}

	// Validate the profile belongs to this account
	if err := db.DB.Where("id = ? AND account_id = ?", headerID, accountID).First(&profile).Error; err != nil {
		return profile, fmt.Errorf("profile not found or does not belong to account")
	}

	return profile, nil
}

// POST /library
func AddToLibrary(c echo.Context) error {
	// 1. Get Inputs
	userID := c.Get("user_id").(uuid.UUID)
	keys, err := getUserKeys(userID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "user not found"})
	}
	if keys.MDBList == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "MDBList API key not configured"})
	}
	if keys.TMDB == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "TMDB API key not configured"})
	}

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

	err = services.AddToLibrary(MdbClient, TmdbClient, keys.MDBList, keys.TMDB, req.ExternalID, req.MediaType, profile.ID)
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

	// Response structure matching tmdb.Result
	type LibraryResult struct {
		ID           any    `json:"id"` // int (tmdb) or string (imdb)
		Title        string `json:"title,omitempty"`
		Name         string `json:"name,omitempty"`
		PosterPath   string `json:"poster_path"`
		BackdropPath string `json:"backdrop_path"`
		MediaType    string `json:"media_type"`
		Overview     string `json:"overview"`
		ReleaseDate  string `json:"release_date,omitempty"`
		FirstAirDate string `json:"first_air_date,omitempty"`
	}

	var response []LibraryResult
	for _, e := range entries {
		var res LibraryResult
		res.MediaType = e.MediaType // "movie" or "series" -> "movie" or "tv" logic needed?
		// Frontend expects "movie" or "tv" usually, but DB stores "movie"/"series"
		if res.MediaType == "series" {
			res.MediaType = "tv"
		}

		var poster, backdrop string
		// Fetch Images
		var images []models.Image
		db.DB.Where("owner_id = ?", e.MediaID).Find(&images)
		for _, img := range images {
			if img.Type == "poster" {
				// Serve as local API URL
				poster = "/images/" + getFileName(img.LocalPath)
			} else if img.Type == "backdrop" {
				backdrop = "/images/" + getFileName(img.LocalPath)
			}
		}
		res.PosterPath = poster
		res.BackdropPath = backdrop

		if e.MediaType == "movie" {
			var m models.Movie
			if err := db.DB.First(&m, e.MediaID).Error; err == nil {
				res.Title = m.Title
				res.Overview = m.Overview
				if m.ReleaseDate != nil {
					res.ReleaseDate = m.ReleaseDate.Format("2006-01-02")
				}
				// Extract ID
				if val, ok := m.ExternalIDs["tmdb"]; ok {
					res.ID = val
				} else if val, ok := m.ExternalIDs["imdb"]; ok {
					res.ID = val
				} else {
					res.ID = m.ID.String() // Fallback to UUID
				}
			}
		} else {
			// Is Series
			var s models.Series
			if err := db.DB.First(&s, e.MediaID).Error; err == nil {
				res.Name = s.Title
				res.Overview = s.Overview
				// Extract ID
				if val, ok := s.ExternalIDs["tmdb"]; ok {
					res.ID = val
				} else if val, ok := s.ExternalIDs["imdb"]; ok {
					res.ID = val
				} else {
					res.ID = s.ID.String()
				}
			}
		}

		response = append(response, res)
	}

	// Wrapper to match TMDB "results" key if needed, or just list
	// TMDB Search returns { page: ..., results: [...] }
	// Frontend DiscoveryProvider expects List<DiscoveryItem> directly usually?
	// Wait, provider uses `DiscoveryRepo.search` which calls `tmdb.Client.Search`?
	// Let's match TMDB SearchResponse structure: { page: 1, results: [...] }
	return c.JSON(http.StatusOK, map[string]any{
		"results":     response,
		"page":        page,
		"total_pages": 1, // Mock
	})
}

// Helper to extract filename from path
func getFileName(path string) string {
	// Assuming path is like /home/.../assets/poster.jpg
	// We want just poster.jpg if we serve specific dir
	// But api.go serves "./assets" at "/api/v1/images"
	// So if local path is "./assets/poster.jpg", we return "poster.jpg"
	// Since we don't know the absolute structure, best is to split by /
	// However, AddToLibrary saves `LocalPath`
	// We need to ensure we serve the correct relative path.
	// For now assume flat structure in assets or preserve hierarchy relative to assets?
	// Let's just return the base name for safety if everything is in assets root.
	// But `DownloadImage` might save full path.
	// Hack: splitting by "assets/"
	parts := strings.Split(path, "assets/")
	if len(parts) > 1 {
		return parts[1]
	}
	// Fallback: basename
	parts = strings.Split(path, "/")
	return parts[len(parts)-1]
}

// GET /library/check/:id
func CheckLibrary(c echo.Context) error {
	// 1. Get Profile
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	externalID := c.Param("id") // e.g. "tt123", "tm123" or just "123"

	// 2. Check if exists
	exists := false

	// Check Movies
	var movie models.Movie
	if err := db.DB.Where("(external_ids ->> 'imdb' = ? OR external_ids ->> 'tmdb' = ?) AND profile_id = ?", externalID, externalID, profile.ID).First(&movie).Error; err == nil {
		exists = true
	} else {
		// Check Series
		var series models.Series
		if err := db.DB.Where("(external_ids ->> 'imdb' = ? OR external_ids ->> 'tmdb' = ?) AND profile_id = ?", externalID, externalID, profile.ID).First(&series).Error; err == nil {
			exists = true
		}
	}

	return c.JSON(http.StatusOK, map[string]bool{"in_library": exists})
}

// DELETE /library/:id
func RemoveFromLibrary(c echo.Context) error {
	// 1. Get Profile
	userID := c.Get("user_id").(uuid.UUID)
	profile, err := getActiveProfile(c, userID)
	if err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "no profile found"})
	}

	externalID := c.Param("id")

	// 2. Transact Deletion
	found := false
	err = db.DB.Transaction(func(tx *gorm.DB) error {
		// Check Movie
		var movie models.Movie
		if err := tx.Where("(external_ids ->> 'imdb' = ? OR external_ids ->> 'tmdb' = ?) AND profile_id = ?", externalID, externalID, profile.ID).First(&movie).Error; err == nil {
			// Found Movie
			found = true
			// Cascade Delete: Images, Credits?
			// GORM constraints usually handle cascade if set, otherwise we might manually delete related objects
			// Assuming "OnDelete:CASCADE" or similar in migration, or rely on GORM AutoMigrate for associations if setup
			// But polymorphic relations often need manual cleanup.
			// Ideally LibraryEntry also needs deletion.

			// Delete LibraryEntry
			tx.Where("media_id = ? AND profile_id = ?", movie.ID, profile.ID).Delete(&models.LibraryEntry{})

			// Delete Images (Polymorphic owner)
			tx.Where("owner_id = ? AND owner_type = ?", movie.ID, "Movie").Delete(&models.Image{})

			// Delete Movie
			return tx.Delete(&movie).Error
		}

		// Check Series
		var series models.Series
		if err := tx.Where("(external_ids ->> 'imdb' = ? OR external_ids ->> 'tmdb' = ?) AND profile_id = ?", externalID, externalID, profile.ID).First(&series).Error; err == nil {
			found = true

			// Delete LibraryEntry
			tx.Where("media_id = ? AND profile_id = ?", series.ID, profile.ID).Delete(&models.LibraryEntry{})

			// Find Seasons to delete Images for them
			var seasons []models.Season
			tx.Where("series_id = ?", series.ID).Find(&seasons)
			for _, s := range seasons {
				tx.Where("owner_id = ? AND owner_type = ?", s.ID, "Season").Delete(&models.Image{})
				// Episodes?
			}
			tx.Where("series_id = ?", series.ID).Delete(&models.Season{})
			// Episodes cascade from Season usually?

			// Delete Series Images
			tx.Where("owner_id = ? AND owner_type = ?", series.ID, "Series").Delete(&models.Image{})

			return tx.Delete(&series).Error
		}

		return nil
	})

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	if !found {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "media not found in library"})
	}

	return c.JSON(http.StatusOK, map[string]bool{"success": true})
}

// GET /library/tv/:id/seasons
// Mirrors behavior of /discover/tv/:id/seasons
func GetLibraryShowSeasons(c echo.Context) error {
	idParam := c.Param("id") // TMDB ID from route

	// 1. Find Series by TMDB ID
	var series models.Series
	// GORM raw JSON query or iterate?
	// Postgres: external_ids ->> 'tmdb' = ?
	if err := db.DB.Where("external_ids ->> 'tmdb' = ?", idParam).First(&series).Error; err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "series not found in library"})
	}

	// 2. Fetch Seasons
	var dbSeasons []models.Season
	db.DB.Where("series_id = ?", series.ID).Order("season_number asc").Find(&dbSeasons)

	// 3. Map to TMDB Season struct
	type TmdbSeason struct {
		ID           int    `json:"id"`
		Name         string `json:"name"`
		Overview     string `json:"overview"`
		PosterPath   string `json:"poster_path"`
		SeasonNumber int    `json:"season_number"`
		AirDate      string `json:"air_date"`
	}

	var results []TmdbSeason
	for _, s := range dbSeasons {
		// Fetch Image
		var posterPath string
		var img models.Image
		if err := db.DB.Where("owner_id = ? AND type = ?", s.ID, "poster").First(&img).Error; err == nil {
			posterPath = "/images/" + getFileName(img.LocalPath)
		}

		// Extract ID
		tmdbID := 0
		if val, ok := s.ExternalIDs["tmdb"]; ok {
			// JSON nums come as float64 usually in generic maps, need care
			if f, ok := val.(float64); ok {
				tmdbID = int(f)
			} else if i, ok := val.(int); ok {
				tmdbID = i
			}
		}

		results = append(results, TmdbSeason{
			ID:           tmdbID,
			Name:         s.Title,
			Overview:     s.Overview,
			PosterPath:   posterPath,
			SeasonNumber: s.SeasonNumber,
		})
	}

	return c.JSON(http.StatusOK, results)
}

// GET /library/tv/:id/season/:num
// Mirrors /discover/tv/:id/season/:num
func GetLibrarySeasonEpisodes(c echo.Context) error {
	idParam := c.Param("id")
	seasonNum := c.Param("num")

	// 1. Find Series
	var series models.Series
	if err := db.DB.Where("external_ids ->> 'tmdb' = ?", idParam).First(&series).Error; err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "series not found"})
	}

	// 2. Find Season
	var season models.Season
	if err := db.DB.Where("series_id = ? AND season_number = ?", series.ID, seasonNum).First(&season).Error; err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "season not found"})
	}

	// 3. Fetch Episodes
	var dbEpisodes []models.Episode
	db.DB.Where("season_id = ?", season.ID).Order("episode_number asc").Find(&dbEpisodes)

	// 4. Map to TMDB SeasonDetails struct (Episodes list)
	type TmdbEpisode struct {
		ID            int    `json:"id"`
		Name          string `json:"name"`
		Overview      string `json:"overview"`
		StillPath     string `json:"still_path"`
		EpisodeNumber int    `json:"episode_number"`
		Runtime       int    `json:"runtime"`
	}

	type TmdbSeasonDetails struct {
		ID           int           `json:"id"`
		Name         string        `json:"name"`
		PosterPath   string        `json:"poster_path"`
		SeasonNumber int           `json:"season_number"`
		Episodes     []TmdbEpisode `json:"episodes"`
	}

	var episodes []TmdbEpisode
	for _, e := range dbEpisodes {
		episodes = append(episodes, TmdbEpisode{
			Name:          e.Title,
			Overview:      e.Overview,
			EpisodeNumber: e.EpisodeNumber,
			Runtime:       e.Runtime,
			// Add ID/Image logic if stored
		})
	}

	// Get Season Poster again
	var posterPath string
	var img models.Image
	if err := db.DB.Where("owner_id = ? AND type = ?", season.ID, "poster").First(&img).Error; err == nil {
		posterPath = "/images/" + getFileName(img.LocalPath)
	}

	resp := TmdbSeasonDetails{
		Name:         season.Title,
		PosterPath:   posterPath,
		SeasonNumber: season.SeasonNumber,
		Episodes:     episodes,
	}

	return c.JSON(http.StatusOK, resp)
}

package api

import (
	"net/http"
	"rivulet_server/internal/auth"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

func Start() {
	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Public Routes
	e.GET("/api/v1/system/info", GetSystemInfo)
	e.POST("/api/v1/auth/register", auth.Register) // Temp helper
	e.POST("/api/v1/auth/login", auth.Login)
	e.POST("/api/v1/auth/verify", auth.Verify)

	// Static assets
	e.Static("/api/v1/images", "./assets")

	// Protected Routes (Group)
	v1 := e.Group("/api/v1")
	v1.Use(auth.RequireAuth) // Apply middleware

	// Health check
	v1.GET("/health", func(c echo.Context) error {
		// Example of accessing the user ID from the token
		userID := c.Get("user_id")
		return c.JSON(http.StatusOK, map[string]any{
			"status": "healthy",
			"user":   userID,
		})
	})

	// Config
	v1.GET("/user/config", GetUserConfig)
	v1.POST("/user/config", UpdateUserConfig)

	// Discovery
	v1.GET("/discover/search", Search)
	v1.GET("/discover/details/:id", GetDetails)
	v1.GET("/discover/tv/:id/seasons", GetShowSeasons)
	v1.GET("/discover/tv/:id/season/:num", GetSeasonEpisodes)

	// Real Debrid
	v1.POST("/rd/unrestrict", Unrestrict)

	// Torrent scraping
	v1.GET("/stream/scrape", ScrapeStreams)

	// Torrent Resolve
	v1.POST("/stream/resolve", ResolveStream)

	// Profiles
	v1.GET("/profiles", ListProfiles)
	v1.POST("/profiles", CreateProfile)

	// Favorites
	favorites := v1.Group("/favorites")
	favorites.POST("", AddFavorite)
	favorites.DELETE("", RemoveFavorite)
	favorites.POST("/check", CheckFavorites)

	// Library
	library := v1.Group("/library")
	library.POST("", AddToLibrary)
	library.GET("", GetLibrary)
	library.GET("/check/:id", CheckLibrary)
	library.DELETE("/:id", RemoveFromLibrary)
	library.GET("/tv/:id/seasons", GetLibraryShowSeasons)
	library.GET("/tv/:id/season/:num", GetLibrarySeasonEpisodes)

	// History
	v1.POST("/history/progress", UpdateProgress)
	v1.DELETE("/history/progress", DeleteProgress)
	v1.GET("/history", GetProfileHistory)
	v1.GET("/history/media", GetMediaHistory)

	e.Logger.Fatal(e.Start(":8080"))
}

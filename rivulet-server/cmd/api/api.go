package api

import (
	"net/http"
	"rivulet_server/cmd/models"
	_ "rivulet_server/docs"
	"rivulet_server/internal/auth"
	"rivulet_server/internal/db"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	echoSwagger "github.com/swaggo/echo-swagger"
)

// --- Helpers ---

func MapAuthResultToResponse(result auth.AuthResult) models.Response {
	if result.Success {
		return models.Success(result.Code, result.Data)
	}
	return models.Error(result.Code, result.Data)
}

// Helper function for requests that have complex logic to get account_id.
// If the caller is an Admin, we get the `account_id` from the query parameter.
// If the caller is an User, we get the `account_id` from the context.
// If a User Account calls the endpoint with an `account_id` query parameter, it will be rejected.
// Response: 400
func GetAccountIdLogic(c echo.Context) (uuid.UUID, *models.ErrorResponse) {
	role := c.Get("role").(db.Role)
	if role == db.RoleAdmin {
		// This means the caller is an Admin account. We get the `account_id` from the query parameter.
		_accountId, err := uuid.Parse(c.QueryParam("account_id"))
		if err != nil {
			return uuid.UUID{}, &models.ErrorResponse{Code: http.StatusBadRequest, Error: "Invalid account_id"}
		}
		return _accountId, nil
	} else {
		// This means the caller is an User account. We get the `account_id` from the context.
		if c.QueryParam("account_id") != "" {
			return uuid.UUID{}, &models.ErrorResponse{Code: http.StatusBadRequest, Error: "User accounts cannot use the `account_id` parameter. Please call this endpoint without the account_id parameter"}
		}
		return c.Get("account_id").(uuid.UUID), nil
	}
}

// --- Handlers ---

func Start() {
	e := echo.New()
	e.Use(middleware.RequestLogger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	v1 := e.Group("/api/v1")

	// Public Routes
	v1.GET("/health", GetHealth)
	v1.POST("/account/admin/first", CreateFirstAdminAccount)
	v1.POST("/auth/login", Login)
	v1.POST("/auth/refresh", Refresh)

	v1.GET("/swagger/*", echoSwagger.WrapHandler)
	v1.GET("/swagger", func(c echo.Context) error {
		return c.Redirect(http.StatusMovedPermanently, "swagger/index.html")
	})

	// Static assets
	// e.Static("/api/v1/images", "./assets")

	// Protected Routes
	protected := v1.Group("")
	protected.Use(auth.RequireAuth)

	// Authentication
	auth := protected.Group("/auth")
	auth.GET("/health", GetAuthHealth)
	auth.POST("/logout", Logout)
	auth.DELETE("/session", EndSession)
	auth.GET("/session/all", GetActiveSessions)
	auth.DELETE("/session/all", EndAllSessions)

	// Account management
	account := protected.Group("/account")

	account.POST("/admin", CreateAdminAccount)
	account.GET("/admin", GetAllAdminAccounts)
	account.PUT("/admin", UpdateAdminAccount)
	account.DELETE("/admin", DeleteAdminAccount)

	account.POST("/user", CreateUserAccount)
	account.GET("/user", GetAllUserAccounts)
	account.PUT("/user", UpdateUserAccount)
	account.DELETE("/user", DeleteUserAccount)

	// Profile management
	profile := protected.Group("/profile")
	profile.POST("", CreateProfile)
	profile.GET("", GetProfiles)
	profile.PUT("", UpdateProfile)
	profile.DELETE("", DeleteProfile)

	e.Logger.Fatal(e.Start(":8080"))
}

// --- General Routes ---

// @Summary      Check server availability
// @Description  Check server availability. This endpoint will only fail if the server is not running.
// @Tags         General
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Router       /api/v1/health [get]
func GetHealth(c echo.Context) error {
	return models.Success(http.StatusOK, "OK").ToResponse(c)
}

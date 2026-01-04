package auth

import (
	"net/http"
	"rivulet_server/cmd/models"
	"rivulet_server/internal/db"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
)

// Responses: 401
func RequireAuth(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		// Get header
		authHeader := c.Request().Header.Get("Authorization")
		if authHeader == "" {
			return models.Error(http.StatusUnauthorized, "Missing Authorization Header").ToResponse(c)
		}

		// Parse "Bearer <token>"
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			return models.Error(http.StatusUnauthorized, "Invalid Header Format").ToResponse(c)
		}
		tokenString := parts[1]

		// Verify Token
		token, err := jwt.ParseWithClaims(tokenString, &AccessClaims{}, func(token *jwt.Token) (any, error) {
			return JwtSecret, nil
		})

		if err != nil || !token.Valid {
			return models.Error(http.StatusUnauthorized, "Invalid or Expired Token").ToResponse(c)
		}

		// Inject User into Context for downstream handlers
		claims := token.Claims.(*AccessClaims)
		c.Set("account_id", claims.AccountId)
		c.Set("role", claims.Role)

		return next(c)
	}
}

// Responses: 403
func RequireAdmin(c echo.Context) error {
	var role db.Role = c.Get("role").(db.Role)
	if role != db.RoleAdmin {
		return models.Error(http.StatusForbidden, "Forbidden. Only Admins are allowed to access this endpoint").ToResponse(c)
	}
	return nil
}

// Responses 403
func RequireUser(c echo.Context) error {
	var role db.Role = c.Get("role").(db.Role)
	if role != db.RoleUser {
		return models.Error(http.StatusForbidden, "Forbidden. Only Users are allowed to access this endpoint").ToResponse(c)
	}
	return nil
}

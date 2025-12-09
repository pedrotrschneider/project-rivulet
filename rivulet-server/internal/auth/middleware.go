package auth

import (
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
)

func RequireAuth(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		// 1. Get header
		authHeader := c.Request().Header.Get("Authorization")
		if authHeader == "" {
			return echo.NewHTTPError(401, "Missing Authorization Header")
		}

		// 2. Parse "Bearer <token>"
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			return echo.NewHTTPError(401, "Invalid Header Format")
		}
		tokenString := parts[1]

		// 3. Verify Token
		token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
			return JwtSecret, nil
		})

		if err != nil || !token.Valid {
			return echo.NewHTTPError(401, "Invalid or Expired Token")
		}

		// 4. Inject User into Context for downstream handlers
		claims := token.Claims.(*Claims)
		c.Set("user_id", claims.AccountID)
		c.Set("is_admin", claims.IsAdmin)

		return next(c)
	}
}
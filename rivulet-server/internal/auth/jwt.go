package auth

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// Define your secret key (In production, load from os.Getenv)
var JwtSecret = []byte("super_secret_dev_key_change_me")

type Claims struct {
	AccountID uuid.UUID `json:"account_id"`
	IsAdmin   bool      `json:"is_admin"`
	jwt.RegisteredClaims
}

func GenerateTokens(accountID uuid.UUID, isAdmin bool) (string, string, error) {
	// 1. Access Token (Short lived: 1 hour)
	claims := &Claims{
		AccountID: accountID,
		IsAdmin:   isAdmin,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(1 * time.Hour)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	accessToken, err := token.SignedString(JwtSecret)
	if err != nil {
		return "", "", err
	}

	// 2. Refresh Token (Long lived: 30 days)
	refreshClaims := &Claims{
		AccountID: accountID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * 24 * time.Hour)),
		},
	}
	refreshTokenObj := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshToken, err := refreshTokenObj.SignedString(JwtSecret)

	return accessToken, refreshToken, err
}
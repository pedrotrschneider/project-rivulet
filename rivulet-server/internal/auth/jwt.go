package auth

import (
	"rivulet_server/internal/db"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// Define your secret key (In production, load from os.Getenv)
var JwtSecret = []byte("super_secret_dev_key_change_me")

type AccessClaims struct {
	AccountId uuid.UUID `json:"account_id"`
	Role      db.Role   `json:"role"`
	jwt.RegisteredClaims
}

type RefreshClaims struct {
	AccountId uuid.UUID `json:"account_id"`
	FamilyId  uuid.UUID `json:"family_id"`
	Role      db.Role   `json:"role"`
	jwt.RegisteredClaims
}

type AccessToken struct {
	Claims AccessClaims
	Token  string
}

type RefreshToken struct {
	Claims RefreshClaims
	Token  string
}

func GenerateTokensWithFamilyId(accountId uuid.UUID, role db.Role, familyId uuid.UUID) (AccessToken, RefreshToken, error) {
	// Access Token (Short lived: 5 minutes)
	accessClaims := &AccessClaims{
		AccountId: accountId,
		Role:      role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(5 * time.Minute)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := token.SignedString(JwtSecret)
	if err != nil {
		return AccessToken{}, RefreshToken{}, err
	}

	// Refresh Token (Long lived: 30 days)
	refreshClaims := &RefreshClaims{
		AccountId: accountId,
		FamilyId:  familyId,
		Role:      role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * 24 * time.Hour)),
		},
	}
	refreshTokenObj := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshTokenObj.SignedString(JwtSecret)
	if err != nil {
		return AccessToken{}, RefreshToken{}, err
	}

	accessToken := AccessToken{
		Claims: *accessClaims,
		Token:  accessTokenString,
	}

	refreshToken := RefreshToken{
		Claims: *refreshClaims,
		Token:  refreshTokenString,
	}

	return accessToken, refreshToken, nil
}

func GenerateTokens(accountId uuid.UUID, role db.Role) (AccessToken, RefreshToken, error) {
	return GenerateTokensWithFamilyId(accountId, role, uuid.New())
}

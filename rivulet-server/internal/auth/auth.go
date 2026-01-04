package auth

import (
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"rivulet_server/internal/db"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// --- Models ---

type TokenGroup struct {
	AccessToken  string
	RefreshToken string
	Role         string
}

type AuthResult struct {
	Success bool
	Code    int
	Data    string
}

func AuthError(code int, message string) AuthResult {
	return AuthResult{
		Success: false,
		Code:    code,
		Data:    message,
	}
}

func AuthSuccess(code int, message string) AuthResult {
	return AuthResult{
		Success: true,
		Code:    code,
		Data:    message,
	}
}

func AuthTokensSuccess(accessToken, refreshToken, role string) AuthResult {
	return AuthResult{
		Success: true,
		Code:    http.StatusOK,
		Data:    "",
	}
}

// --- Utilities ---

func HashToken(token string) string {
	hasher := sha256.New()
	hasher.Write([]byte(token))
	hashBytes := hasher.Sum(nil)
	return hex.EncodeToString(hashBytes)
}

func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	return string(bytes), err
}

func CheckPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// Responses: 200, 500
func saveRefreshToken(refreshToken RefreshToken, userAgent, ipAddress string) AuthResult {
	refreshTokenHash := HashToken(refreshToken.Token)
	accountRefreshToken := db.AccountRefreshToken{
		AccountId:  refreshToken.Claims.AccountId,
		TokenHash:  refreshTokenHash,
		FamilyId:   refreshToken.Claims.FamilyId,
		IsRevoked:  false,
		ExpiresAt:  refreshToken.Claims.RegisteredClaims.ExpiresAt.Time,
		DeviceName: userAgent,
		IpAddress:  ipAddress,
	}

	if err := db.DB.Create(&accountRefreshToken).Error; err != nil {
		return AuthError(http.StatusInternalServerError, err.Error())
	}

	return AuthSuccess(http.StatusOK, "Refresh Token saved successfully")
}

// --- Handlers ---

// Responses: 201, 400, 500
func Register(email, password string, role db.Role) AuthResult {
	tx := db.DB.Begin()

	hashed, _ := HashPassword(password)
	account := db.Account{
		Email:        email,
		PasswordHash: hashed,
		Role:         role,
	}

	if err := tx.Create(&account).Error; err != nil {
		tx.Rollback()
		return AuthError(http.StatusBadRequest, "User likely exists")
	}

	profile := db.UserProfile{
		AccountId: account.Id,
		Name:      "Default",
		Avatar:    "https://api.dicebear.com/7.x/bottts/svg?seed=Default", // Placeholder
	}

	if err := tx.Create(&profile).Error; err != nil {
		tx.Rollback()
		return AuthError(http.StatusInternalServerError, "Failed to create profile")
	}

	if err := tx.Commit().Error; err != nil {
		return AuthError(http.StatusInternalServerError, "Failed to commit transaction")
	}

	return AuthSuccess(http.StatusCreated, "User created")
}

// Responses: 200, 401, 500
func Login(email, password, userAgent, ipAddress string) (*TokenGroup, AuthResult) {
	var account db.Account
	if err := db.DB.Where("email = ?", email).First(&account).Error; err != nil {
		return nil, AuthError(http.StatusUnauthorized, "Invalid credentials")
	}

	if !CheckPassword(password, account.PasswordHash) {
		return nil, AuthError(http.StatusUnauthorized, "Invalid credentials")
	}

	access, refresh, err := GenerateTokens(account.Id, account.Role)
	if err != nil {
		return nil, AuthError(http.StatusInternalServerError, "Token generation failed")
	}

	saveRefreshToken(refresh, userAgent, ipAddress)

	return &TokenGroup{
		AccessToken:  access.Token,
		RefreshToken: refresh.Token,
		Role:         account.Role.ToString(),
	}, AuthSuccess(http.StatusOK, "Logged in successfully")
}

// Responses: 200, 401, 500
func Refresh(refreshToken, userAgent, ipAddress string) (*TokenGroup, AuthResult) {
	token, err := jwt.ParseWithClaims(refreshToken, &RefreshClaims{}, func(token *jwt.Token) (any, error) {
		return JwtSecret, nil
	})

	if err != nil || !token.Valid {
		return nil, AuthError(http.StatusUnauthorized, "Invalid or Expired Token")
	}

	familyId := token.Claims.(*RefreshClaims).FamilyId
	role := token.Claims.(*RefreshClaims).Role

	storedRefreshToken := db.AccountRefreshToken{}
	if err := db.DB.Where("token_hash = ?", HashToken(refreshToken)).First(&storedRefreshToken).Error; err != nil {
		return nil, AuthError(http.StatusUnauthorized, "Invalid or Expired Token")
	}
	if storedRefreshToken.IsRevoked {
		// Someone tried to use a refresh token that has been revoked before
		// This likely means a refresh token from this family was stolen. We invalidate all tokens from this family.
		DeleteTokenFamily(storedRefreshToken.FamilyId)
		return nil, AuthError(http.StatusUnauthorized, "Invalid or Expired Token")
	}

	refreshTokens := []db.AccountRefreshToken{}
	db.DB.Where("family_id = ?", familyId).Find(&refreshTokens)

	for _, refreshToken := range refreshTokens {
		if refreshToken.IsRevoked {
			continue
		}
		refreshToken.IsRevoked = true
		db.DB.Save(&refreshToken)
	}

	access, refresh, err := GenerateTokensWithFamilyId(token.Claims.(*RefreshClaims).AccountId, role, familyId)
	if err != nil {
		return nil, AuthError(http.StatusInternalServerError, "Token generation failed")
	}

	saveRefreshToken(refresh, userAgent, ipAddress)

	return &TokenGroup{
		AccessToken:  access.Token,
		RefreshToken: refresh.Token,
		Role:         role.ToString(),
	}, AuthSuccess(http.StatusOK, "Logged in successfully")
}

// Responses: 200, 401, 404, 500
func EndSession(refreshToken string) AuthResult {
	token, err := jwt.ParseWithClaims(refreshToken, &RefreshClaims{}, func(token *jwt.Token) (any, error) {
		return JwtSecret, nil
	})

	if err != nil || !token.Valid {
		return AuthError(http.StatusUnauthorized, "Invalid or Expired Token")
	}

	tokenHash := HashToken(token.Raw)
	if err := db.DB.Where("token_hash = ?", tokenHash).First(&db.AccountRefreshToken{}).Error; err != nil {
		return AuthError(http.StatusNotFound, "Couldn't find Refresh Token")
	}

	return DeleteTokenFamily(token.Claims.(*RefreshClaims).FamilyId)
}

// Responses: 200, 500
func DeleteTokenFamily(familyId uuid.UUID) AuthResult {
	if err := db.DB.Where("family_id = ?", familyId).Delete(&db.AccountRefreshToken{}).Error; err != nil {
		return AuthError(http.StatusInternalServerError, "Failed to delete Refresh Token Family")
	}

	return AuthSuccess(http.StatusOK, "Logged out successfully")
}
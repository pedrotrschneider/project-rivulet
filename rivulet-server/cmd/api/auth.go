package api

import (
	"net/http"
	"rivulet_server/cmd/models"
	"rivulet_server/internal/auth"
	"rivulet_server/internal/db"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// --- Helpers ---

func MapTokenGroupToAuthResponse(tokenGroup *auth.TokenGroup) models.AuthResponse {
	return models.AuthResponse{
		AccessToken:  tokenGroup.AccessToken,
		RefreshToken: tokenGroup.RefreshToken,
		Role:         tokenGroup.Role,
	}
}

func MapDbAccountRefreshTokensToSessionResponse(rts []db.AccountRefreshToken) models.GetSessionResponse {
	response := models.GetSessionResponse{
		AccountId: rts[0].AccountId,
		Sessions:  []models.GetSessionResponseItem{},
	}

	for _, session := range rts {
		response.Sessions = append(response.Sessions, models.GetSessionResponseItem{
			AccountId:  session.AccountId,
			FamilyId:   session.FamilyId,
			CreatedAt:  session.CreatedAt,
			ExpiresAt:  session.ExpiresAt,
			DeviceName: session.DeviceName,
			IpAddress:  session.IpAddress,
		})
	}

	return response
}

// --- Handlers ---

// @Router       /api/v1/auth/health [get]
// @Summary      Check server availability while authenticated
// @Description  Check server availability while authenticated. This endpoint will fail if the caller is not authenticated.
// @Security     BearerAuth
// @Tags         Auth
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 401  {object}  models.ErrorResponse
func GetAuthHealth(c echo.Context) error {
	return models.Success(http.StatusOK, "OK").ToResponse(c)
}

// @Router       /api/v1/auth/login [post]
// @Summary      Login into an Admin or User account.
// @Description  Login into an Admin or User account. This endpoint is unauthenticated.
// @Tags         Auth
//
// @Accept       json
// @Param        request  body  models.LoginRequest  true  "Login"
//
// @Produce      json
// @Success      200  {object}  models.AuthResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func Login(c echo.Context) error {
	var req models.LoginRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	tokenGroup, result := auth.Login(req.Email, req.Password, c.Request().UserAgent(), c.RealIP())
	if result.Success {
		return models.EmptySuccess(result.Code).JSON(c, MapTokenGroupToAuthResponse(tokenGroup))
	}
	return models.Error(result.Code, result.Data).ToResponse(c)
}

// @Router       /api/v1/auth/refresh [post]
// @Summary      Refresh an Admin or User account's Access and Refresh Tokens.
// @Description  Refresh an Admin or User account's Access and Refresh Tokens. This endpoint is unauthenticated.
// @Tags         Auth
//
// @Accept       json
// @Param        request  body  models.RefreshRequest  true  "Refresh"
//
// @Produce      json
// @Success      200  {object}  models.AuthResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func Refresh(c echo.Context) error {
	var req models.RefreshRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	tokenGroup, result := auth.Refresh(req.RefreshToken, c.Request().UserAgent(), c.RealIP())
	if result.Success {
		return models.EmptySuccess(result.Code).JSON(c, MapTokenGroupToAuthResponse(tokenGroup))
	}
	return models.Error(result.Code, result.Data).ToResponse(c)
}

// @Router       /api/v1/auth/logout [post]
// @Summary      Logout from an Admin or User account.
// @Description  Logout from an Admin or User account. This endpoint is authenticated.
// @Security     BearerAuth
// @Tags         Auth
//
// @Accept       json
// @Param        request  body  models.LogoutRequest  true  "Logout"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func Logout(c echo.Context) error {
	var req models.LogoutRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	result := auth.EndSession(req.RefreshToken)
	if result.Success {
		return models.Success(result.Code, result.Data).ToResponse(c)
	}
	return models.Error(result.Code, result.Data).ToResponse(c)
}

// @Router       /api/v1/auth/session/all [get]
// @Summary      Get active sessions for an Admin or User account.
// @Description  Get active sessions for an Admin or User account. This endpoint is authenticated. If the caller is Admin, the `account_id` query parameter is required. If the caller is User, the `account_id` query parameter is ignored.
// @Security     BearerAuth
// @Tags         Auth
//
// @Accept       json
// @Param        account_id  query  string  false  "Account ID"
//
// @Produce      json
// @Success      200  {object}  models.GetSessionResponse[]
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func GetActiveSessions(c echo.Context) error {
	accountId, err := GetAccountIdLogic(c)
	if err != nil {
		return err.ToResponse(c)
	}

	var account db.Account
	if err := db.DB.Where("id = ?", accountId).First(&account).Error; err != nil {
		return models.Error(http.StatusNotFound, "Account not found").ToResponse(c)
	}

	var sessions []db.AccountRefreshToken
	if err := db.DB.Where("account_id = ? AND is_revoked = false", accountId).Find(&sessions).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to get active sessions").ToResponse(c)
	}

	if len(sessions) == 0 {
		return models.EmptySuccess(http.StatusOK).JSON(c, models.GetSessionResponse{
			AccountId: accountId,
			Role:      account.Role.ToString(),
			Sessions:  []models.GetSessionResponseItem{},
		})
	}

	response := MapDbAccountRefreshTokensToSessionResponse(sessions)
	response.Role = account.Role.ToString()

	return models.EmptySuccess(http.StatusOK).JSON(c, response)
}

// @Router       /api/v1/auth/session [delete]
// @Summary      End a session for an Admin or User account.
// @Description  End a session for an Admin or User account. This endpoint is authenticated. If the caller is Admin, they can end sessions for both Admin and User Accounts. If the caller is User, they can only end their own sessions.
// @Security     BearerAuth
// @Tags         Auth
//
// @Accept       json
// @Param        family_id  query  string  true  "Family ID"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func EndSession(c echo.Context) error {
	familyId, err := uuid.Parse(c.QueryParam("family_id"))
	if err != nil {
		return models.Error(http.StatusBadRequest, "Invalid family_id").ToResponse(c)
	}

	accountId := c.Get("account_id").(uuid.UUID)
	role := c.Get("role").(db.Role)

	if role == db.RoleUser {
		// If the role is User, the account_id of the caller must match the account_id of the refresh tokens of the session.
		var refreshToken db.AccountRefreshToken
		if err := db.DB.Where("family_id = ? AND is_revoked = false", familyId).First(&refreshToken).Error; err != nil {
			return models.Error(http.StatusInternalServerError, "Failed to get active sessions").ToResponse(c)
		}
		if refreshToken.AccountId != accountId {
			return models.Error(http.StatusUnauthorized, "Unauthorized").ToResponse(c)
		}
	}

	result := auth.DeleteTokenFamily(familyId)
	if result.Success {
		return models.Success(result.Code, result.Data).ToResponse(c)
	}
	return models.Error(result.Code, result.Data).ToResponse(c)
}

// @Router       /api/v1/auth/session/all [delete]
// @Summary      End all sessions for an Admin or User account.
// @Description  End all sessions for an Admin or User account. This endpoint is authenticated. If the caller is Admin, they can end sessions for both Admin and User Accounts. If the caller is User, they can only end their own sessions.
// @Security     BearerAuth
// @Tags         Auth
//
// @Accept       json
// @Param        account_id  query  string  false  "Account ID"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func EndAllSessions(c echo.Context) error {
	accountId, err := GetAccountIdLogic(c)
	if err != nil {
		return err.ToResponse(c)
	}

	var account db.Account
	if err := db.DB.Where("id = ?", accountId).First(&account).Error; err != nil {
		return models.Error(http.StatusNotFound, "Account not found").ToResponse(c)
	}

	if err := db.DB.Where("account_id = ?", accountId).Delete(&db.AccountRefreshToken{}).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to delete sessions").ToResponse(c)
	}

	return models.Success(http.StatusOK, "Logged out from all devices").ToResponse(c)
}

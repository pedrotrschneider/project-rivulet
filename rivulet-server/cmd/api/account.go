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

func MapDbAccountToResponse(account db.Account) models.GetAccountResponse {
	return models.GetAccountResponse{
		Id:        account.Id,
		Email:     account.Email,
		Role:      account.Role.ToString(),
		CreatedAt: account.CreatedAt,
		UpdatedAt: account.UpdatedAt,
	}
}

// --- Handlers ---

// @Router       /api/v1/account/admin [post]
// @Summary      Create first admin account
// @Description  Create first admin account. This endpoint is unathenticated, and will fail if an admin account already exists.
// @Tags         Account
//
// @Accept       json
// @Param        request  body  models.CreateAccountRequest  true  "Create first admin account"
//
// @Produce      json
// @Success      201  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 409  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func CreateFirstAdminAccount(c echo.Context) error {
	var adminAccount db.Account
	if db.DB.Where("role = ?", db.RoleAdmin).First(&adminAccount).Error == nil {
		return models.Error(http.StatusConflict, "Admin Account already exists").ToResponse(c)
	}

	var req models.CreateAccountRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	result := auth.Register(req.Email, req.Password, db.RoleAdmin)
	return MapAuthResultToResponse(result).ToResponse(c)
}

// @Router       /api/v1/account/admin [get]
// @Summary      Get all admin accounts
// @Description  Get all admin accounts. This endpoint is authenticated, and will fail if the user is not an admin.
// @Security     BearerAuth
// @Tags         Account
//
// @Produce      json
// @Success      200  {object}  []models.GetAccountResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func GetAllAdminAccounts(c echo.Context) error {
	if err := auth.RequireAdmin(c); err != nil {
		return err
	}

	var accounts []db.Account
	if err := db.DB.Where("role = ?", db.RoleAdmin).Find(&accounts).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to get admin accounts").ToResponse(c)
	}

	var responseAccounts []models.GetAccountResponse
	for _, account := range accounts {
		responseAccounts = append(responseAccounts, MapDbAccountToResponse(account))
	}

	return models.EmptySuccess(http.StatusOK).JSON(c, responseAccounts)
}

// @Router       /api/v1/account/admin [post]
// @Summary      Create admin account
// @Description  Create admin account. This endpoint is authenticated, and will fail if the user is not an admin.
// @Security     BearerAuth
// @Tags         Account
//
// @Accept       json
// @Param        request  body  models.CreateAccountRequest  true  "Create admin account"
//
// @Produce      json
// @Success      201  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func CreateAdminAccount(c echo.Context) error {
	if err := auth.RequireAdmin(c); err != nil {
		return err
	}

	var req models.CreateAccountRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	result := auth.Register(req.Email, req.Password, db.RoleAdmin)
	return MapAuthResultToResponse(result).ToResponse(c)
}

// @Router       /api/v1/account/admin [delete]
// @Summary      Delete admin account
// @Description  Delete admin account. This endpoint is authenticated, and will fail if the user is not an admin.
// @Security     BearerAuth
// @Tags         Account
//
// @Accept       json
// @Param        account_id query string true "Delete admin account"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func DeleteAdminAccount(c echo.Context) error {
	if err := auth.RequireAdmin(c); err != nil {
		return err
	}

	accountId, err := uuid.Parse(c.QueryParam("account_id"))
	if err != nil {
		return models.Error(http.StatusBadRequest, "Invalid account_id").ToResponse(c)
	}

	account := db.Account{}
	if err := db.DB.Where("id = ?", accountId).First(&account).Error; err != nil {
		return models.Error(http.StatusNotFound, "Admin Account not found").ToResponse(c)
	}

	if err := db.DB.Delete(&db.Account{}, "id = ?", accountId).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to delete Admin Account").ToResponse(c)
	}
	return models.Success(http.StatusOK, "Admin Account deleted successfully").ToResponse(c)
}

// @Router       /api/v1/account/admin [put]
// @Summary      Update admin account
// @Description  Update admin account. This endpoint is authenticated, and will fail if the user is not an admin.
// @Security     BearerAuth
// @Tags         Account
//
// @Accept       json
// @Param        account_id  query  string  true  "Update admin account"
// @Param        request  body  models.ChangePasswordRequest  true  "Update admin account"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func UpdateAdminAccount(c echo.Context) error {
	if err := auth.RequireAdmin(c); err != nil {
		return err
	}

	var accountId uuid.UUID = c.Get("account_id").(uuid.UUID)

	account := db.Account{}
	if err := db.DB.Where("id = ?", accountId).First(&account).Error; err != nil {
		return models.Error(http.StatusNotFound, "Admin Account not found").ToResponse(c)
	}

	if account.Role != db.RoleAdmin {
		return models.Error(http.StatusForbidden, "Account is not an Admin Account").ToResponse(c)
	}

	var req models.ChangePasswordRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	account.PasswordHash, _ = auth.HashPassword(req.NewPassword)
	if err := db.DB.Save(&account).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to update Admin Account").ToResponse(c)
	}

	return models.Success(http.StatusOK, "Admin account updated successfully").ToResponse(c)
}

// @Router       /api/v1/account/user [get]
// @Summary      Get all user accounts
// @Description  Get all user accounts. This endpoint is authenticated, and will fail if the user is not an admin.
// @Security     BearerAuth
// @Tags         Account
//
// @Produce      json
// @Success      200  {object}  []models.GetAccountResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func GetAllUserAccounts(c echo.Context) error {
	if err := auth.RequireAdmin(c); err != nil {
		return err
	}

	var accounts []db.Account
	if err := db.DB.Where("role = ?", db.RoleUser).Find(&accounts).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to get user accounts").ToResponse(c)
	}

	var responseAccounts []models.GetAccountResponse
	for _, account := range accounts {
		responseAccounts = append(responseAccounts, MapDbAccountToResponse(account))
	}

	return models.EmptySuccess(http.StatusOK).JSON(c, responseAccounts)
}

// @Router       /api/v1/account/user [post]
// @Summary      Create user account
// @Description  Create user account. This endpoint is authenticated, and will fail if the user is not an admin.
// @Security     BearerAuth
// @Tags         Account
//
// @Accept       json
// @Param        request  body  models.CreateAccountRequest  true  "Create user account"
//
// @Produce      json
// @Success      201  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func CreateUserAccount(c echo.Context) error {
	if err := auth.RequireAdmin(c); err != nil {
		return err
	}

	var req models.CreateAccountRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	result := auth.Register(req.Email, req.Password, db.RoleUser)
	return MapAuthResultToResponse(result).ToResponse(c)
}

// @Router       /api/v1/account/user [delete]
// @Summary      Delete user account
// @Description  Delete user account. This endpoint is authenticated, and will fail if the user is not an admin.
// @Security     BearerAuth
// @Tags         Account
//
// @Accept       json
// @Param        account_id  query  string  true  "Delete user account"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func DeleteUserAccount(c echo.Context) error {
	if err := auth.RequireAdmin(c); err != nil {
		return err
	}

	accountId, err := uuid.Parse(c.QueryParam("account_id"))
	if err != nil {
		return models.Error(http.StatusBadRequest, "Invalid account_id").ToResponse(c)
	}

	account := db.Account{}
	if err := db.DB.Where("id = ?", accountId).First(&account).Error; err != nil {
		return models.Error(http.StatusNotFound, "User Account not found").ToResponse(c)
	}

	if account.Role != db.RoleUser {
		return models.Error(http.StatusForbidden, "Account is not a User Account").ToResponse(c)
	}

	if err := db.DB.Delete(&db.Account{}, "id = ?", accountId).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to delete User Account").ToResponse(c)
	}
	return models.Success(http.StatusOK, "User Account deleted successfully").ToResponse(c)
}

// @Router       /api/v1/account/user [put]
// @Summary      Update user account
// @Description  Update user account. This endpoint is authenticated. If the caller is Admin, the account provided in the `account_id` query parameter will be updated. If the caller is User, the account that called the endpoint will be updated.
// @Security     BearerAuth
// @Tags         Account
//
// @Accept       json
// @Param        account_id  query  string  true  "Update user account. This parameter is only used if the caller is Admin."
// @Param        request  body  models.ChangePasswordRequest  true  "Update user account"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func UpdateUserAccount(c echo.Context) error {
	var accountId uuid.UUID
	role := c.Get("role").(db.Role)
	if role == db.RoleUser {
		// This means the caller is User. Use the account_id of the caller.
		if c.QueryParam("account_id") != "" {
			return models.Error(http.StatusBadRequest, "User accounts cannot change the password of another account. Please call this endpoint without the account_id query parameter.").ToResponse(c)
		}

		accountId = c.Get("account_id").(uuid.UUID)
	} else {
		// This means the caller is Admin. Use the account_id from the query parameter.
		_accountId, err := uuid.Parse(c.QueryParam("account_id"))
		if err != nil {
			return models.Error(http.StatusBadRequest, "Invalid account_id").ToResponse(c)
		}
		accountId = _accountId
	}

	account := db.Account{}
	if err := db.DB.Where("id = ?", accountId).First(&account).Error; err != nil {
		return models.Error(http.StatusNotFound, "User Account not found").ToResponse(c)
	}

	if account.Role != db.RoleUser {
		return models.Error(http.StatusForbidden, "Account is not a User Account").ToResponse(c)
	}

	var req models.ChangePasswordRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	account.PasswordHash, _ = auth.HashPassword(req.NewPassword)
	if err := db.DB.Save(&account).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to update User Account").ToResponse(c)
	}
	return models.Success(http.StatusOK, "User Account updated successfully").ToResponse(c)
}

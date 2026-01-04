package api

import (
	"net/http"
	"rivulet_server/cmd/models"
	"rivulet_server/internal/db"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// --- Helpers ---

func MapDbAddonsToGetAddonsResponseItem(dbAddons []db.AccountAddon) models.GetAddonsResponse {
	var response models.GetAddonsResponse
	response.Addons = []models.GetAddonsResponseItem{}
	for _, dbAddon := range dbAddons {
		response.Addons = append(response.Addons, models.GetAddonsResponseItem{
			Id:          dbAddon.Id,
			ManifestUrl: dbAddon.ManifestUrl,
			Priority:    dbAddon.Priority,
		})
	}
	return response
}

// --- Handlers ---

// @Router       /api/v1/addon [post]
// @Summary      Install addon
// @Description  Install addon. This endpoint is authenticated. If the caller is Admin, the addon will be installed on the account provided in the `account_id` query parameter. If the caller is User, the addon will be installed on the account that called the endpoint. If the caller is User and provides the `account_id` query parameter, it will be rejected.
// @Security     BearerAuth
// @Tags         Addon
//
// @Accept       json
// @Param        account_id  query  string                      true  "Install addon. This parameter is only used if the caller is Admin."
// @Param        request     body   models.InstallAddonRequest  true  "Install addon"
//
// @Produce      json
// @Success      201  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func InstallAddon(c echo.Context) error {
	accountId, err := GetAccountIdLogic(c)
	if err != nil {
		return err.ToResponse(c)
	}

	var account db.Account
	if err := db.DB.Where("id = ?", accountId).First(&account).Error; err != nil {
		return models.Error(http.StatusNotFound, "Account not found").ToResponse(c)
	}

	if account.Role != db.RoleUser {
		return models.Error(http.StatusForbidden, "Forbidden. Can only install addons on User Accounts").ToResponse(c)
	}

	var req models.InstallAddonRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	addon := db.AccountAddon{
		AccountId:   accountId,
		ManifestUrl: req.ManifestUrl,
		Priority:    req.Priority,
	}

	if err := db.DB.Create(&addon).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to install addon").ToResponse(c)
	}

	return models.Success(http.StatusCreated, "Addon installed successfully").ToResponse(c)
}

// @Router       /api/v1/addon [get]
// @Summary      Get installed addons
// @Description  Get installed addons. This endpoint is authenticated. If the caller is Admin, the addons of the account provided in the `account_id` query parameter will be returned. If the caller is User, the addons of the account that called the endpoint will be returned.
// @Security     BearerAuth
// @Tags         Addon
//
// @Param        account_id  query  string  true  "Get installed addons. This parameter is only used if the caller is Admin."
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func GetInstalledAddons(c echo.Context) error {
	accountId, err := GetAccountIdLogic(c)
	if err != nil {
		return err.ToResponse(c)
	}

	var account db.Account
	if err := db.DB.Where("id = ?", accountId).First(&account).Error; err != nil {
		return models.Error(http.StatusNotFound, "Account not found").ToResponse(c)
	}

	if account.Role != db.RoleUser {
		return models.Error(http.StatusForbidden, "Forbidden. Only User Accounts can have addons").ToResponse(c)
	}

	var addons []db.AccountAddon
	if err := db.DB.Where("account_id = ?", accountId).Order("priority DESC").Find(&addons).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to get addons").ToResponse(c)
	}

	res := MapDbAddonsToGetAddonsResponseItem(addons)
	res.AccountId = accountId
	return models.EmptySuccess(http.StatusOK).JSON(c, res)
}

// @Router       /api/v1/addon [put]
// @Summary      Update installed addon
// @Description  Update installed addon. This endpoint is authenticated. If the caller is User, they will only be able to update addons from their own account.
// @Security     BearerAuth
// @Tags         Addon
//
// @Accept       json
// @Param        addon_id  query  string                     true  "Update installed addon"
// @Param        request   body   models.UpdateAddonRequest  true  "Update installed addon"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func UpdateInstalledAddon(c echo.Context) error {
	accountId := c.Get("account_id").(uuid.UUID)
	role := c.Get("role").(db.Role)

	addonId, parseErr := uuid.Parse(c.QueryParam("addon_id"))
	if parseErr != nil {
		return models.Error(http.StatusBadRequest, "Invalid addon_id").ToResponse(c)
	}

	var addon db.AccountAddon
	if err := db.DB.Where("id = ?", addonId).First(&addon).Error; err != nil {
		return models.Error(http.StatusNotFound, "Addon not found").ToResponse(c)
	}

	if role == db.RoleUser && addon.AccountId != accountId {
		return models.Error(http.StatusForbidden, "Forbidden. User Accounts can only update addons from their own account.").ToResponse(c)
	}

	var req models.UpdateAddonRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	addon.Priority = req.Priority

	if err := db.DB.Save(&addon).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to update addon").ToResponse(c)
	}

	return models.Success(http.StatusOK, "Addon updated successfully").ToResponse(c)
}

// @Router       /api/v1/addon [delete]
// @Summary      Uninstall addon
// @Description  Uninstall addon. This endpoint is authenticated. If the caller is User, they will only be able to delete addons from their own account.
// @Security     BearerAuth
// @Tags         Addon
//
// @Param        addon_id  query  string  true  "Uninstall addon"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func UninstallAddon(c echo.Context) error {
	accountId := c.Get("account_id").(uuid.UUID)
	role := c.Get("role").(db.Role)

	addonId, parseErr := uuid.Parse(c.QueryParam("addon_id"))
	if parseErr != nil {
		return models.Error(http.StatusBadRequest, "Invalid addon_id").ToResponse(c)
	}

	var addon db.AccountAddon
	if err := db.DB.Where("id = ?", addonId).First(&addon).Error; err != nil {
		return models.Error(http.StatusNotFound, "Addon not found").ToResponse(c)
	}

	if role == db.RoleUser && addon.AccountId != accountId {
		return models.Error(http.StatusForbidden, "Forbidden. User Accounts can only delete addons from their own account.").ToResponse(c)
	}

	if err := db.DB.Delete(&addon).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to uninstall addon").ToResponse(c)
	}

	return models.Success(http.StatusOK, "Addon uninstalled successfully").ToResponse(c)
}
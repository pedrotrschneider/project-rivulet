package api

import (
	"net/http"
	"rivulet_server/cmd/models"
	"rivulet_server/internal/db"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// --- Helpers ---

func MapDbProfilesToProfilesResponse(profiles []db.UserProfile) models.GetProfilesResponse {
	var response models.GetProfilesResponse
	response.Profiles = []models.GetProfilesResponseItem{}
	for _, profile := range profiles {
		response.Profiles = append(response.Profiles, models.GetProfilesResponseItem{
			Id:     profile.Id,
			Name:   profile.Name,
			Avatar: profile.Avatar,
		})
	}
	return response
}

// --- Handlers ---

// @Router       /api/v1/profile [post]
// @Summary      Create a new profile
// @Description  Create a new profile for the current account if the caller is a User, of the provided account if the caller is an Admin.
// @Security     BearerAuth
// @Tags         Profile
//
// @Accept       json
// @Param        account_id  query  string                      false  "Account ID"
// @Param        request     body   models.CreateProfileRequest true   "Create Profile Request"
//
// @Produce      json
// @Success      201  {object}  models.SuccessResponse
// @Failure      400  {object}  models.ErrorResponse
// @Failure      401  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
func CreateProfile(c echo.Context) error {
	accountId, err := GetAccountIdLogic(c)
	if err != nil {
		return err.ToResponse(c)
	}

	var req models.CreateProfileRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	profile := db.UserProfile{
		AccountId: accountId,
		Name:      req.Name,
		Avatar:    req.Avatar,
	}

	if err := db.DB.Create(&profile).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to create profile").ToResponse(c)
	}
	return models.Success(http.StatusCreated, "Profile created successfully").ToResponse(c)
}

// @Router       /api/v1/profile [get]
// @Summary      Get profiles
// @Description  Get profiles for the current account if the caller is a User, of the provided account if the caller is an Admin.
// @Security     BearerAuth
// @Tags         Profile
//
// @Accept       json
// @Param        account_id  query  string  false  "Account ID"
//
// @Produce      json
// @Success      200  {object}  models.GetProfilesResponse
// @Failure      400  {object}  models.ErrorResponse
// @Failure      401  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
func GetProfiles(c echo.Context) error {
	accountId, err := GetAccountIdLogic(c)
	if err != nil {
		return err.ToResponse(c)
	}

	var profiles []db.UserProfile
	if err := db.DB.Where("account_id = ?", accountId).Find(&profiles).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to get profiles").ToResponse(c)
	}

	res := MapDbProfilesToProfilesResponse(profiles)
	res.AccountId = accountId
	return models.EmptySuccess(http.StatusOK).JSON(c, res)
}

// @Router       /api/v1/profile [put]
// @Summary      Update profile
// @Description  Update profile for the current account if the caller is a User, of the provided account if the caller is an Admin.
// @Security     BearerAuth
// @Tags         Profile
//
// @Accept       json
// @Param        profile_id  query  string                      true   "Profile ID"
// @Param        request     body   models.CreateProfileRequest true   "Update Profile Request"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure      400  {object}  models.ErrorResponse
// @Failure      401  {object}  models.ErrorResponse
// @Failure      403  {object}  models.ErrorResponse
// @Failure      404  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
func UpdateProfile(c echo.Context) error {
	accountId := c.Get("account_id").(uuid.UUID)
	role := c.Get("role").(db.Role)

	// Get the requested profile id
	profileId, perr := uuid.Parse(c.QueryParam("profile_id"))
	if perr != nil {
		return models.Error(http.StatusBadRequest, "Invalid profile_id").ToResponse(c)
	}

	// Get the profile from the db
	var profile db.UserProfile
	if err := db.DB.Where("id = ?", profileId).First(&profile).Error; err != nil {
		return models.Error(http.StatusNotFound, "Profile not found").ToResponse(c)
	}

	// If the caller is not an Admin, they can only update their own profiles
	if role != db.RoleAdmin && profile.AccountId != accountId {
		return models.Error(http.StatusForbidden, "Forbidden. User accounts can only update their own profiles").ToResponse(c)
	}

	// Get the request body
	var req models.CreateProfileRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	// Update only the fields that have been provided in the request
	if req.Name != "" {
		profile.Name = req.Name
	}
	if req.Avatar != "" {
		profile.Avatar = req.Avatar
	}

	// Update the profile in the db
	if err := db.DB.Where("id = ?", profileId).Updates(&profile).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to update profile").ToResponse(c)
	}
	return models.Success(http.StatusOK, "Profile updated successfully").ToResponse(c)
}

// @Router       /api/v1/profile [delete]
// @Summary      Delete profile
// @Description  Delete profile for the current account if the caller is a User, of the provided account if the caller is an Admin.
// @Security     BearerAuth
// @Tags         Profile
//
// @Accept       json
// @Param        profile_id  query  string  true "Profile ID"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure      400  {object}  models.ErrorResponse
// @Failure      401  {object}  models.ErrorResponse
// @Failure      403  {object}  models.ErrorResponse
// @Failure      404  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
func DeleteProfile(c echo.Context) error {
	accountId := c.Get("account_id").(uuid.UUID)
	role := c.Get("role").(db.Role)

	// Get the requested profile id
	profileId, perr := uuid.Parse(c.QueryParam("profile_id"))
	if perr != nil {
		return models.Error(http.StatusBadRequest, "Invalid profile_id").ToResponse(c)
	}

	// Get the profile from the db
	var profile db.UserProfile
	if err := db.DB.Where("id = ?", profileId).First(&profile).Error; err != nil {
		return models.Error(http.StatusNotFound, "Profile not found").ToResponse(c)
	}

	// If the caller is not an Admin, they can only delete their own profiles
	if role != db.RoleAdmin && profile.AccountId != accountId {
		return models.Error(http.StatusForbidden, "Forbidden. User accounts can only delete their own profiles").ToResponse(c)
	}

	// Delete the profile
	if err := db.DB.Where("id = ?", profileId).Delete(&profile).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to delete profile").ToResponse(c)
	}
	return models.Success(http.StatusOK, "Profile deleted successfully").ToResponse(c)
}
package api

import (
	"net/http"
	"rivulet_server/cmd/models"
	"rivulet_server/internal/db"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// --- Helpers ---

func MapDbFavoritesToGetFavoritesResponse(favorites []db.FavoriteStream) models.GetFavoritesResponse {
	res := models.GetFavoritesResponse{
		Favorites: make([]models.GetFavoritesRsponseItem, len(favorites)),
	}
	for i, favorite := range favorites {
		res.Favorites[i] = models.GetFavoritesRsponseItem{
			Id:      favorite.Base.Id,
			AddonId: favorite.AddonId,
			ImdbId:  favorite.ImdbId,
			Title:   favorite.Title,
		}
	}
	return res
}

// --- Handlers ---

// @Router       /api/v1/favorite [post]
// @Summary      Add favorite stream
// @Description  Add favorite stream. This endpoint is authenticated. If the caller is User, they will only be able to add favorites from their own account.
// @Security     BearerAuth
// @Tags         Favorite
//
// @Accept       json
// @Param        request   body   models.AddFavoriteRequest  true  "Add favorite stream"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func AddFavoriteStream(c echo.Context) error {
	role := c.Get("role").(db.Role)
	if role != db.RoleUser {
		return models.Error(http.StatusForbidden, "Forbidden. Only Users are allowed to access this endpoint").ToResponse(c)
	}

	profileId, err := uuid.Parse(c.Request().Header.Get("X-Profile-Id"))
	if err != nil {
		return models.Error(http.StatusBadRequest, "Invalid profile_id").ToResponse(c)
	}

	if err := db.DB.Where("id = ?", profileId).Find(&db.UserProfile{}).Error; err != nil {
		return models.Error(http.StatusNotFound, "Profile not found").ToResponse(c)
	}

	var req models.AddFavoriteRequest
	if err := c.Bind(&req); err != nil {
		return err
	}

	if err := db.DB.Where("account_id = ? AND id = ?", c.Get("account_id").(uuid.UUID), req.AddonId).First(&db.AccountAddon{}).Error; err != nil {
		return models.Error(http.StatusNotFound, "Addon not found on your account").ToResponse(c)
	}

	favorite := db.FavoriteStream{
		AccountId: c.Get("account_id").(uuid.UUID),
		ProfileId: profileId,
		AddonId:   req.AddonId,
		ImdbId:    req.ImdbId,
		Title:     req.Title,
	}

	if err := db.DB.Create(&favorite).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to add favorite stream").ToResponse(c)
	}

	return models.Success(http.StatusOK, "Favorite stream added").ToResponse(c)
}

// @Router       /api/v1/favorite [get]
// @Summary      Get favorite streams
// @Description  Get favorite streams. This endpoint is authenticated. If the caller is User, they will only be able to get favorites from their own account.
// @Security     BearerAuth
// @Tags         Favorite
//
// @Param        imdb_id  query  string  false  "Get favorite streams"
// @Param        addon_id  query  string  false  "Get favorite streams"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func GetFavoriteStreams(c echo.Context) error {
	role := c.Get("role").(db.Role)
	if role != db.RoleUser {
		return models.Error(http.StatusForbidden, "Forbidden. Only Users are allowed to access this endpoint").ToResponse(c)
	}

	accountId := c.Get("account_id").(uuid.UUID)
	profileId, err := uuid.Parse(c.Request().Header.Get("X-Profile-Id"))
	if err != nil {
		return models.Error(http.StatusBadRequest, "Invalid profile_id").ToResponse(c)
	}

	imdb_id := c.QueryParam("imdb_id")
	addon_id := c.QueryParam("addon_id")

	query := db.DB.Where("account_id = ? AND profile_id = ?", accountId, profileId)
	if imdb_id != "" {
		query = query.Where("imdb_id = ?", imdb_id)
	}
	if addon_id != "" {
		query = query.Where("addon_id = ?", addon_id)
	}

	var favorites []db.FavoriteStream
	if err := query.Find(&favorites).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to get favorite streams").ToResponse(c)
	}

	res := MapDbFavoritesToGetFavoritesResponse(favorites)
	res.AccountId = accountId
	res.ProfileId = profileId

	return models.EmptySuccess(http.StatusOK).JSON(c, res)
}

// @Router       /api/v1/favorite [delete]
// @Summary      Remove favorite stream
// @Description  Remove favorite stream. This endpoint is authenticated. If the caller is User, they will only be able to remove favorites from their own account.
// @Security     BearerAuth
// @Tags         Favorite
//
// @Param        favorite_id  query  string  true  "Remove favorite stream"
//
// @Produce      json
// @Success      200  {object}  models.SuccessResponse
// @Failure		 400  {object}  models.ErrorResponse
// @Failure		 401  {object}  models.ErrorResponse
// @Failure		 403  {object}  models.ErrorResponse
// @Failure		 404  {object}  models.ErrorResponse
// @Failure		 500  {object}  models.ErrorResponse
func RemoveFavoriteStream(c echo.Context) error {
	role := c.Get("role").(db.Role)
	if role != db.RoleUser {
		return models.Error(http.StatusForbidden, "Forbidden. Only Users are allowed to access this endpoint").ToResponse(c)
	}

	accountId := c.Get("account_id").(uuid.UUID)

	profileId, parseErr := uuid.Parse(c.Request().Header.Get("X-Profile-Id"))
	if parseErr != nil {
		return models.Error(http.StatusBadRequest, "Invalid profile_id").ToResponse(c)
	}

	favoriteId, parseErr := uuid.Parse(c.QueryParam("favorite_id"))
	if parseErr != nil {
		return models.Error(http.StatusBadRequest, "Invalid favorite_id").ToResponse(c)
	}

	var favorite db.FavoriteStream
	if err := db.DB.Where("id = ?", favoriteId).First(&favorite).Error; err != nil {
		return models.Error(http.StatusNotFound, "Favorite stream not found").ToResponse(c)
	}

	if favorite.AccountId != accountId || favorite.ProfileId != profileId {
		return models.Error(http.StatusForbidden, "You can only remove favorite streams from your own account").ToResponse(c)
	}

	if err := db.DB.Where("id = ?", favoriteId).Delete(&db.FavoriteStream{}).Error; err != nil {
		return models.Error(http.StatusInternalServerError, "Failed to remove favorite stream").ToResponse(c)
	}

	return models.Success(http.StatusOK, "Favorite stream removed").ToResponse(c)
}

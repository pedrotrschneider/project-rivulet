package models

import (
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// --- General ---

// Responses

type Response interface {
	ToResponse(c echo.Context) error
	JSON(c echo.Context, body interface{}) error
}

type ErrorResponse struct {
	Code  int    `json:"-"`
	Error string `json:"error"`
}

func Error(code int, message string) ErrorResponse {
	return ErrorResponse{
		Code:  code,
		Error: message,
	}
}

func (e ErrorResponse) ToResponse(c echo.Context) error {
	return c.JSON(e.Code, e)
}

func (e ErrorResponse) JSON(c echo.Context, body interface{}) error {
	return c.JSON(e.Code, body)
}

type SuccessResponse struct {
	Code    int    `json:"-"`
	Message string `json:"message"`
}

func Success(code int, message string) SuccessResponse {
	return SuccessResponse{
		Code:    code,
		Message: message,
	}
}

func EmptySuccess(code int) SuccessResponse {
	return SuccessResponse{
		Code:    code,
		Message: "",
	}
}

func (s SuccessResponse) ToResponse(c echo.Context) error {
	return c.JSON(s.Code, s)
}

func (s SuccessResponse) JSON(c echo.Context, body interface{}) error {
	return c.JSON(s.Code, body)
}

/// --- Auth ---

// Requests

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type LogoutRequest struct {
	RefreshToken string `json:"refresh_token"`
}

// Responses

type AuthResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	Role         string `json:"role"`
}

type GetSessionResponse struct {
	AccountId uuid.UUID                `json:"account_id"`
	Role      string                   `json:"role"`
	Sessions  []GetSessionResponseItem `json:"sessions"`
}

type GetSessionResponseItem struct {
	AccountId  uuid.UUID `json:"account_id"`
	FamilyId   uuid.UUID `json:"family_id"`
	CreatedAt  time.Time `json:"created_at"`
	ExpiresAt  time.Time `json:"expires_at"`
	DeviceName string    `json:"device_name"`
	IpAddress  string    `json:"ip_address"`
}

// --- Account ---

// Requests

type CreateAccountRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type ChangePasswordRequest struct {
	NewPassword string `json:"new_password"`
}

// Responses

type GetAccountResponse struct {
	Id        uuid.UUID `json:"id"`
	Email     string    `json:"email"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// --- Profile ---

// Requests

type CreateProfileRequest struct {
	Name   string `json:"name"`
	Avatar string `json:"avatar"`
}

// Responses

type GetProfilesResponse struct {
	AccountId uuid.UUID                 `json:"account_id"`
	Profiles  []GetProfilesResponseItem `json:"profiles"`
}

type GetProfilesResponseItem struct {
	Id	   uuid.UUID `json:"id"`
	Name   string    `json:"name"`
	Avatar string    `json:"avatar"`
}

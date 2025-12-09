package auth

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"time"

	"github.com/labstack/echo/v4"
	"golang.org/x/crypto/bcrypt"
	// "gopkg.in/gomail.v2"
	// "gorm.io/gorm"
)

// --- Utilities ---

func hashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	return string(bytes), err
}

func checkPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

func generateOTP() string {
	// Generate random 6 digit number
	n, _ := rand.Int(rand.Reader, big.NewInt(900000))
	return fmt.Sprintf("%d", n.Int64()+100000)
}

func sendEmail(to, otp string) {
	// In Dev, just print it to console to avoid SMTP setup for now
	fmt.Printf("\n🔥🔥🔥\n[SMTP MOCK] To: %s | OTP: %s\n🔥🔥🔥\n\n", to, otp)

	// Real implementation for later:
	// m := gomail.NewMessage()
	// m.SetHeader("From", "auth@rivulet.media")
	// m.SetHeader("To", to)
	// m.SetHeader("Subject", "Your Login Code")
	// m.SetBody("text/html", "Code: <b>"+otp+"</b>")
	// d := gomail.NewDialer("smtp.example.com", 587, "user", "pass")
	// d.DialAndSend(m)
}

// --- Handlers ---

// Register (Optional helper to create first user)
func Register(c echo.Context) error {
	type Request struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	var req Request
	if err := c.Bind(&req); err != nil {
		return err
	}

	hashed, _ := hashPassword(req.Password)
	account := models.Account{
		Email:        req.Email,
		PasswordHash: hashed,
	}

	if result := db.DB.Create(&account); result.Error != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "User likely exists"})
	}

	profile := models.Profile{
		AccountID: account.ID,
		Name:      "Default",
		Avatar:    "https://api.dicebear.com/7.x/bottts/svg?seed=Default", // Placeholder
	}

	if err := db.DB.Create(&profile).Error; err != nil {
		db.DB.Rollback()
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Failed to create profile"})
	}

	db.DB.Commit()

	return c.JSON(http.StatusCreated, map[string]string{"message": "User created"})
}

// 1. Login: Validate Pass -> Gen OTP
func Login(c echo.Context) error {
	type Request struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	var req Request
	if err := c.Bind(&req); err != nil {
		return err
	}

	var account models.Account
	if err := db.DB.Where("email = ?", req.Email).First(&account).Error; err != nil {
		// Mock delay to prevent timing attacks
		time.Sleep(100 * time.Millisecond)
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Invalid credentials"})
	}

	if !checkPassword(req.Password, account.PasswordHash) {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Invalid credentials"})
	}

	// Generate & Save OTP
	otp := generateOTP()
	account.CurrentOtp = otp
	account.OtpExpiresAt = time.Now().Add(5 * time.Minute)
	db.DB.Save(&account)

	// Send Email
	go sendEmail(account.Email, otp)

	return c.JSON(http.StatusOK, map[string]any{
		"message":      "OTP sent to email",
		"otp_required": true,
	})
}

// 2. Verify: Validate OTP -> Issue JWT
func Verify(c echo.Context) error {
	type Request struct {
		Email string `json:"email"`
		Code  string `json:"code"`
	}
	var req Request
	if err := c.Bind(&req); err != nil {
		return err
	}

	var account models.Account
	if err := db.DB.Where("email = ?", req.Email).First(&account).Error; err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "User not found"})
	}

	// Validate OTP
	if account.CurrentOtp != req.Code || time.Now().After(account.OtpExpiresAt) {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Invalid or expired code"})
	}

	// Clear OTP so it can't be reused
	// account.CurrentOtp = "" // Optional: Clear to enforce single-use
	// db.DB.Save(&account)

	// Generate JWTs
	access, refresh, err := GenerateTokens(account.ID, account.IsAdmin)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Token generation failed"})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"access_token":  access,
		"refresh_token": refresh,
	})
}

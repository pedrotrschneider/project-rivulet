package services

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
)

// Ensure this directory exists in your Dockerfile/Setup
const AssetsDir = "./assets"

func DownloadImage(url string) (string, error) {
	if url == "" {
		return "", nil
	}

	// Create assets dir if missing
	if _, err := os.Stat(AssetsDir); os.IsNotExist(err) {
		os.MkdirAll(AssetsDir, 0755)
	}

	// Generate a unique filename (uuid + extension)
	ext := ".jpg"
	if strings.HasSuffix(url, ".png") {
		ext = ".png"
	}
	filename := uuid.New().String() + ext
	localPath := filepath.Join(AssetsDir, filename)

	// Download
	resp, err := http.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// Save to disk
	out, err := os.Create(localPath)
	if err != nil {
		return "", err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return "", err
	}

	// Return relative path for API serving
	return "/api/v1/images/" + filename, nil
}
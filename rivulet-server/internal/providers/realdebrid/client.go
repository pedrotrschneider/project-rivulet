package realdebrid

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"time"
)

type Client struct {
	BaseURL    string
	HttpClient *http.Client
}

func NewClient() *Client {
	return &Client{
		BaseURL: "https://api.real-debrid.com/rest/1.0",
		HttpClient: &http.Client{
			Timeout: 20 * time.Second,
		},
	}
}

// --- Models ---

type User struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	Email    string `json:"email"`
	Premium  int    `json:"premium"` // Days left
	Type     string `json:"type"`    // "premium" or "free"
}

type UnrestrictRequest struct {
	Link string `json:"link"`
}

type UnrestrictResponse struct {
	ID       string `json:"id"`
	Filename string `json:"filename"`
	Download string `json:"download"` // The Direct MP4 Link
}

type File struct {
	ID       int    `json:"id"`
	Path     string `json:"path"`
	Bytes    int64  `json:"bytes"`
	Selected int    `json:"selected"`
}

type TorrentInfo struct {
	ID       string `json:"id"`
	Filename string `json:"filename"`
	Status   string `json:"status"`
	Progress int    `json:"progress"`
	Links    []string `json:"links"`
	Files    []File   `json:"files"`
}

// --- Methods ---

// AddMagnet adds the torrent and returns the ID
func (c *Client) AddMagnet(token, magnet string) (string, error) {
	data := url.Values{}
	data.Set("magnet", magnet)

	resp, err := c.doRequest("POST", "/torrents/addMagnet", token, []byte(data.Encode()))
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 201 {
		return "", fmt.Errorf("failed to add magnet: %d", resp.StatusCode)
	}

	var result struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	return result.ID, nil
}

// GetTorrentInfo checks the status
func (c *Client) GetTorrentInfo(token, id string) (*TorrentInfo, error) {
	resp, err := c.doRequest("GET", "/torrents/info/"+id, token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var info TorrentInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return nil, err
	}
	return &info, nil
}

// SelectFiles is needed because sometimes a magnet stays in "waiting_files_selection"
// status until you explicitly say "Download everything"
func (c *Client) SelectFiles(token, id string, fileIDs string) error {
	data := url.Values{}
	data.Set("files", fileIDs) // "all" or "1,2,3"

	resp, err := c.doRequest("POST", fmt.Sprintf("/torrents/selectFiles/%s", id), token, []byte(data.Encode()))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
    // 204 No Content is success, 202 is "Action already done"
	if resp.StatusCode != 204 && resp.StatusCode != 202 {
		return fmt.Errorf("select files failed: %d", resp.StatusCode)
	}
	return nil
}

// Helper to add Auth Header
func (c *Client) doRequest(method, endpoint, token string, body []byte) (*http.Response, error) {
	u := fmt.Sprintf("%s%s", c.BaseURL, endpoint)
	log.Printf("RD Request: %s %s", method, u)
	req, err := http.NewRequest(method, u, bytes.NewBuffer(body))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", "Bearer "+token)
	if body != nil {
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

	return c.HttpClient.Do(req)
}

func (c *Client) GetUser(token string) (*User, error) {
	resp, err := c.doRequest("GET", "/user", token, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("RD Error: %s", resp.Status)
	}

	var user User
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		return nil, err
	}
	return &user, nil
}

func (c *Client) UnrestrictLink(token, link string) (*UnrestrictResponse, error) {
	// RD expects form-urlencoded for POST
	data := url.Values{}
	data.Set("link", link)

	resp, err := c.doRequest("POST", "/unrestrict/link", token, []byte(data.Encode()))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("RD Unrestrict Failed: %s", resp.Status)
	}

	var result UnrestrictResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return &result, nil
}
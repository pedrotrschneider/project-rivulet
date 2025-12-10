package mdblist

import (
	"encoding/json"
	"fmt"
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
		BaseURL: "https://mdblist.com/api",
		HttpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// --- Data Models (Simplified) ---

type SearchResult struct {
	Search []struct {
		ID       string  `json:"id"` // usually imdb_id or numeric
		Title    string  `json:"title"`
		Year     int     `json:"year"`
		Type     string  `json:"type"` // "movie" or "show"
		ImdbID   string  `json:"imdbid"`
		Score    float64 `json:"score"`
		Poster   string  `json:"poster"` // MDBList might return this or we fetch details
	} `json:"search"`
	Response bool `json:"response"`
}

type MediaDetail struct {
	Title       string `json:"title"`
	Year        int    `json:"year"`
	Description string `json:"description"`
	ImdbID      string `json:"imdbid"`
	TmdbID      int    `json:"tmdbid"`
	Type        string `json:"type"`
	Poster      string `json:"poster"`
	Backdrop    string `json:"backdrop"`
	Logo        string `json:"logo"`
	Ratings     []struct {
		Source string `json:"source"`
		Value  any    `json:"value"`
	} `json:"ratings"`
}

// --- Methods ---

func (c *Client) Search(apiKey, query string) (*SearchResult, error) {
	u, _ := url.Parse(fmt.Sprintf("%s/", c.BaseURL))
	q := u.Query()
	q.Add("apikey", apiKey)
	q.Add("s", query)
	u.RawQuery = q.Encode()

	resp, err := c.HttpClient.Get(u.String())
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result SearchResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return &result, nil
}

// GetDetails handles both IMDB and TMDB IDs
func (c *Client) GetDetails(apiKey, id, mediaType string) (*MediaDetail, error) {
	u, _ := url.Parse(fmt.Sprintf("%s/", c.BaseURL))
	q := u.Query()
	q.Add("apikey", apiKey)

	// Smart ID Detection
	if len(id) > 2 && id[:2] == "tt" {
		q.Add("i", id) // IMDB ID (Usually unique, but type helps)
	} else {
		// TMDB ID handling
		cleanID := id
		if len(id) > 2 && id[:2] == "tm" {
			cleanID = id[2:]
		}
		q.Add("tm", cleanID)

		// 🔧 FIX: Disambiguate TMDB IDs
		// MDBList uses 'm=movie' or 'm=show'
		if mediaType == "tv" || mediaType == "show" || mediaType == "series" {
			q.Add("m", "show")
		} else if mediaType == "movie" {
			q.Add("m", "movie")
		}
	}

	u.RawQuery = q.Encode()

	resp, err := c.HttpClient.Get(u.String())
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// Check for "valid but empty" responses (MDBList sometimes returns 200 with error/empty body)
	var detail MediaDetail
	if err := json.NewDecoder(resp.Body).Decode(&detail); err != nil {
		return nil, err
	}
    
    // MDBList returns empty title if not found
    if detail.Title == "" {
        return nil, fmt.Errorf("item not found in MDBList")
    }

	return &detail, nil
}
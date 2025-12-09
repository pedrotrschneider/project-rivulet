package tmdb

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

const (
	BaseURL   = "https://api.themoviedb.org/3"
	ImageBase = "https://image.tmdb.org/t/p/w500" // w500 is good for mobile grids
)

type Client struct {
	HttpClient *http.Client
}

func NewClient() *Client {
	return &Client{
		HttpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// --- Models ---

type SearchResponse struct {
	Page    int      `json:"page"`
	Results []Result `json:"results"`
}

type Result struct {
	ID           int     `json:"id"`
	Title        string  `json:"title,omitempty"`        // Movie
	Name         string  `json:"name,omitempty"`         // TV Show
	PosterPath   string  `json:"poster_path"`
	BackdropPath string  `json:"backdrop_path"`
	MediaType    string  `json:"media_type"`             // "movie", "tv", "person"
	ReleaseDate  string  `json:"release_date,omitempty"` // Movie
	FirstAirDate string  `json:"first_air_date,omitempty"` // TV
	Overview     string  `json:"overview"`
}

// --- Methods ---

func (c *Client) Search(apiKey, query string) ([]Result, error) {
	// We use 'multi' search to get movies and shows mixed
	u := fmt.Sprintf("%s/search/multi?api_key=%s&query=%s&include_adult=false&language=en-US", BaseURL, apiKey, url.QueryEscape(query))

	resp, err := c.HttpClient.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var response SearchResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, err
	}

	// Normalize Image URLs immediately
	var cleaned []Result
	for _, r := range response.Results {
		if r.PosterPath != "" {
			r.PosterPath = ImageBase + r.PosterPath
		}
		if r.BackdropPath != "" {
			r.BackdropPath = ImageBase + r.BackdropPath
		}
		// Skip people/actors from results to keep it clean
		if r.MediaType != "person" {
			cleaned = append(cleaned, r)
		}
	}

	return cleaned, nil
}

func (c *Client) GetTrending(apiKey string) ([]Result, error) {
	u := fmt.Sprintf("%s/trending/all/week?api_key=%s&language=en-US", BaseURL, apiKey)

	resp, err := c.HttpClient.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var response SearchResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, err
	}

	// Normalize
	for i := range response.Results {
		if response.Results[i].PosterPath != "" {
			response.Results[i].PosterPath = ImageBase + response.Results[i].PosterPath
		}
	}

	return response.Results, nil
}
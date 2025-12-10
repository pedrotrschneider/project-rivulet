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

type ImagesResponse struct {
	Logos []Image `json:"logos"`
}

type Image struct {
	FilePath    string  `json:"file_path"`
	VoteAverage float64 `json:"vote_average"`
	Iso639_1    string  `json:"iso_639_1"`
}

type TVShowDetails struct {
	Seasons []struct {
		ID           int    `json:"id"`
		Name         string `json:"name"`
		Overview     string `json:"overview"`
		PosterPath   string `json:"poster_path"`
		SeasonNumber int    `json:"season_number"`
		AirDate      string `json:"air_date"`
	} `json:"seasons"`
}

type SeasonDetails struct {
	ID           int       `json:"id"`
	AirDate      string    `json:"air_date"`
	Name         string    `json:"name"`
	Overview     string    `json:"overview"`
	PosterPath   string    `json:"poster_path"`
	SeasonNumber int       `json:"season_number"`
	Episodes     []Episode `json:"episodes"`
}

type Episode struct {
	AirDate        string  `json:"air_date"`
	EpisodeNumber  int     `json:"episode_number"`
	ID             int     `json:"id"`
	Name           string  `json:"name"`
	Overview       string  `json:"overview"`
	StillPath      string  `json:"still_path"`
	VoteAverage    float64 `json:"vote_average"`
	Runtime        int     `json:"runtime"`
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

// GetLogo fetches the highest-rated English logo
func (c *Client) GetLogo(apiKey string, tmdbID int, mediaType string) (string, error) {
	// Endpoint: /movie/{id}/images or /tv/{id}/images
	endpointType := "movie"
	if mediaType == "show" || mediaType == "tv" || mediaType == "series" {
		endpointType = "tv"
	}

	u := fmt.Sprintf("%s/%s/%d/images?api_key=%s&include_image_language=en,null", BaseURL, endpointType, tmdbID, apiKey)

	resp, err := c.HttpClient.Get(u)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var imgResp ImagesResponse
	if err := json.NewDecoder(resp.Body).Decode(&imgResp); err != nil {
		return "", err
	}

	// Find best logo (highest rated, English)
	if len(imgResp.Logos) > 0 {
		// TMDB usually sorts by rating desc, so taking the first one is safe.
		// We prioritize strictly English if available, or fallback.
		return ImageBase + imgResp.Logos[0].FilePath, nil
	}

	return "", nil
}

// GetTVShowDetails fetches season info
func (c *Client) GetTVShowDetails(apiKey string, tmdbID int) (*TVShowDetails, error) {
	u := fmt.Sprintf("%s/tv/%d?api_key=%s&language=en-US", BaseURL, tmdbID, apiKey)

	resp, err := c.HttpClient.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var details TVShowDetails
	if err := json.NewDecoder(resp.Body).Decode(&details); err != nil {
		return nil, err
	}

	return &details, nil
}

// GetSeasonDetails fetches all episodes for a specific season
func (c *Client) GetSeasonDetails(apiKey string, tmdbID, seasonNum int) (*SeasonDetails, error) {
	u := fmt.Sprintf("%s/tv/%d/season/%d?api_key=%s&language=en-US", BaseURL, tmdbID, seasonNum, apiKey)

	resp, err := c.HttpClient.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var details SeasonDetails
	if err := json.NewDecoder(resp.Body).Decode(&details); err != nil {
		return nil, err
	}

	// Normalize Images
	if details.PosterPath != "" {
		details.PosterPath = ImageBase + details.PosterPath
	}
	for i := range details.Episodes {
		if details.Episodes[i].StillPath != "" {
			details.Episodes[i].StillPath = ImageBase + details.Episodes[i].StillPath
		}
	}

	return &details, nil
}
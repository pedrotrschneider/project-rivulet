package torrentio

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"rivulet_server/internal/providers"
	"strconv"
	"strings"
	"time"
)

type Client struct {
	BaseURL    string
	HttpClient *http.Client
}

func NewClient() *Client {
	return &Client{
		BaseURL: "https://torrentio.strem.fun",
		HttpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

func (c *Client) Name() string {
	return "Torrentio"
}

// --- Internal JSON Response Models ---
type Response struct {
	Streams []StreamItem `json:"streams"`
}

type StreamItem struct {
	Title    string `json:"title"`
	InfoHash string `json:"infoHash"`
	FileIdx  int    `json:"fileIdx"`
	BehaviorHints *struct { // Sometimes Torrentio puts seeds here
		BingeGroup string `json:"bingeGroup"`
	} `json:"behaviorHints,omitempty"`
}

// --- Regex Parsers ---
// Extract size: "💾 1.2 GB"
var sizeRegex = regexp.MustCompile(`💾\s+(\d+(?:\.\d+)?)\s+(GB|MB)`)
// Extract seeds: "👤 123"
var seedsRegex = regexp.MustCompile(`👤\s*(\d+)`)
// Extract resolution: "4k", "2160p", "1080p"
var resRegex = regexp.MustCompile(`(?i)\b(2160p|4k|1080p|720p|480p)\b`)

func parseMetadata(rawTitle string) (int64, int, string) {
	// 1. Size
	var bytes int64
	sizeMatch := sizeRegex.FindStringSubmatch(rawTitle)
	if len(sizeMatch) >= 3 {
		val, _ := strconv.ParseFloat(sizeMatch[1], 64)
		unit := sizeMatch[2]
		if unit == "GB" {
			bytes = int64(val * 1024 * 1024 * 1024)
		} else if unit == "MB" {
			bytes = int64(val * 1024 * 1024)
		}
	}

	// 2. Seeds
	seeds := 0
	seedMatch := seedsRegex.FindStringSubmatch(rawTitle)
	if len(seedMatch) >= 2 {
		seeds, _ = strconv.Atoi(seedMatch[1])
	}

	// 3. Quality (Resolution)
	quality := "Unknown"
	resMatch := resRegex.FindStringSubmatch(rawTitle)
	if len(resMatch) >= 2 {
		quality = strings.ToLower(resMatch[1])
		if quality == "2160p" {
			quality = "4k"
		}
	}

	return bytes, seeds, quality
}

func (c *Client) Scrape(mediaType, imdbID string, season, episode int) ([]*providers.Stream, error) {
	targetID := imdbID
	if mediaType == "series" || mediaType == "show" {
		targetID = fmt.Sprintf("%s:%d:%d", imdbID, season, episode)
	}

	url := fmt.Sprintf("%s/sort=size%%7Cqualityfilter=other,scr,cam,unknown/stream/%s/%s.json", 
		c.BaseURL, mediaType, targetID)

	if mediaType == "show" {
		url = strings.Replace(url, "/stream/show/", "/stream/series/", 1)
	}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	// Spoof User-Agent to avoid 403
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

	resp, err := c.HttpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("torrentio returned status: %d", resp.StatusCode)
	}

	var result Response
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	var streams []*providers.Stream
	for _, item := range result.Streams {
		size, seeds, quality := parseMetadata(item.Title)
		cleanTitle := strings.Split(item.Title, "\n")[0]
		magnet := fmt.Sprintf("magnet:?xt=urn:btih:%s", item.InfoHash)

		var fIdx *int
		idx := item.FileIdx
		fIdx = &idx

		streams = append(streams, &providers.Stream{
			Title:     cleanTitle,
			Size:      size,
			Hash:      item.InfoHash,
			Magnet:    magnet,
			Seeds:     seeds,
			Quality:   quality,
			Source:    "Torrentio",
			FileIndex: fIdx,
		})
	}

	return streams, nil
}
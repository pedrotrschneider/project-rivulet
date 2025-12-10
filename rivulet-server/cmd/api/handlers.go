package api

import (
	"net/http"
	"rivulet_server/internal/db"
	"rivulet_server/internal/models"
	"rivulet_server/internal/providers"
	"rivulet_server/internal/providers/mdblist"
	"rivulet_server/internal/providers/realdebrid"
	"rivulet_server/internal/providers/tmdb"
	"rivulet_server/internal/providers/torrentio"
	"strings"

	"sort"
	"strconv"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// Global instances (In prod, use dependency injection)
var MdbClient *mdblist.Client
var RdClient *realdebrid.Client
var TmdbClient *tmdb.Client
var ScraperManager *providers.Manager

func InitProviders() {
	// Initialize with your API Key (Add to .env later)
	MdbClient = mdblist.NewClient()
	RdClient = realdebrid.NewClient()
	TmdbClient = tmdb.NewClient()

	// Initialize scrapers
	ScraperManager = providers.NewManager(
		torrentio.NewClient(),
	)
}

// --- Handlers ---

type ResolveRequest struct {
	Magnet string `json:"magnet"`
}

// POST /stream/resolve
func ResolveStream(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	keys, err := getUserKeys(userID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "user not found"})
	}
	if keys.RD == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "RealDebrid API key not configured"})
	}

	var req ResolveRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request"})
	}

	// 1. Add Magnet
	torrentID, err := RdClient.AddMagnet(keys.RD, req.Magnet)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed adding to cloud: " + err.Error()})
	}

	// 2. Check Info immediately
	info, err := RdClient.GetTorrentInfo(keys.RD, torrentID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed checking info"})
	}

	// 3. Handle "Waiting for Selection"
	// If it's a new magnet, RD pauses and asks "Which files?". We must say "All" or smart select.
	if info.Status == "waiting_files_selection" {
		err = RdClient.SelectFiles(keys.RD, torrentID, "all")
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed selecting files"})
		}
		// Re-fetch info to see the new status
		info, _ = RdClient.GetTorrentInfo(keys.RD, torrentID)
	}

	// 4. Decision Time
	if info.Status == "downloaded" {
		// It's Cached! Unrestrict the link immediately.
		// Usually the largest file is the movie.
		// For now, we take the first link.
		if len(info.Links) > 0 {
			unrestricted, err := RdClient.UnrestrictLink(keys.RD, info.Links[0])
			if err == nil {
				return c.JSON(http.StatusOK, map[string]interface{}{
					"status":  "cached",
					"url":     unrestricted.Download,
					"file_id": torrentID,
				})
			}
		}
	}

	// If we are here, it is NOT cached (it's "downloading" or "queued").
	return c.JSON(http.StatusOK, map[string]string{
		"status":  "downloading",
		"message": "Item added to cloud. Download in progress.",
		"file_id": torrentID,
	})
}

// GET /stream/scrape?external_id=imdb:tt123&type=movie&season=1&episode=1
func ScrapeStreams(c echo.Context) error {
	externalID := c.QueryParam("external_id") // e.g. "imdb:tt1375666"
	mediaType := c.QueryParam("type")         // "movie" or "show"

	if externalID == "" || mediaType == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "missing params"})
	}

	// Parse IMDB ID (Strip "imdb:" prefix if present)
	imdbID := externalID
	if len(externalID) > 5 && externalID[:5] == "imdb:" {
		imdbID = externalID[5:]
	}

	// Parse Season/Episode
	season, _ := strconv.Atoi(c.QueryParam("season"))
	episode, _ := strconv.Atoi(c.QueryParam("episode"))

	// 1. Fetch Streams (Concurrent)
	streams := ScraperManager.ScrapeAll(mediaType, imdbID, season, episode)

	if len(streams) == 0 {
		return c.JSON(http.StatusOK, []interface{}{})
	}

	// 3. Sort by Size (Descending)
	sort.Slice(streams, func(i, j int) bool {
		return streams[i].Size > streams[j].Size
	})

	return c.JSON(http.StatusOK, streams)
}

func Search(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	keys, err := getUserKeys(userID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "user not found"})
	}
	if keys.TMDB == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "TMDB API key not configured"})
	}

	query := c.QueryParam("q")
	if query == "" {
		results, err := TmdbClient.GetTrending(keys.TMDB)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		return c.JSON(http.StatusOK, results)
	}

	results, err := TmdbClient.Search(keys.TMDB, query)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, results)
}

func GetDetails(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	keys, err := getUserKeys(userID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "user not found"})
	}
	if keys.MDBList == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "MDBList API key not configured"})
	}
	if keys.TMDB == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "TMDB API key not configured"})
	}

	id := c.Param("id")
	mediaType := c.QueryParam("type")

	// Pass it to the client
	details, err := MdbClient.GetDetails(keys.MDBList, id, mediaType)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	if details.TmdbID != 0 {
		// Determine type for TMDB call
		tmType := "movie"
		if mediaType == "tv" || mediaType == "show" || mediaType == "series" {
			tmType = "tv"
		}

		// If type wasn't passed but MDBList returned "show", use that
		if details.Type == "show" || details.Type == "series" {
			tmType = "tv"
		}

		logoURL, err := TmdbClient.GetLogo(keys.TMDB, details.TmdbID, tmType)
		if err == nil {
			details.Logo = logoURL
		}
	}

	return c.JSON(http.StatusOK, details)
}

// GET /discover/tv/:id/seasons
func GetShowSeasons(c echo.Context) error {
	// 1. Get Keys
	userID := c.Get("user_id").(uuid.UUID)
	keys, err := getUserKeys(userID)
	if err != nil || keys.TMDB == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "TMDB API key not configured"})
	}

	// 2. Parse ID
	idParam := c.Param("id") // Expecting TMDB ID (e.g., "85937")
	tmdbID, err := strconv.Atoi(idParam)
	if err != nil {
		// If it's "tm85937", strip prefix
		if len(idParam) > 2 && idParam[:2] == "tm" {
			tmdbID, _ = strconv.Atoi(idParam[2:])
		} else {
			return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid id format"})
		}
	}

	// 3. Fetch Show Details (contains Season List)
	show, err := TmdbClient.GetTVShowDetails(keys.TMDB, tmdbID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	// 4. Return just the seasons list
	// Normalize posters here if Client doesn't do it for the summary list
	for i := range show.Seasons {
		if show.Seasons[i].PosterPath != "" && !strings.HasPrefix(show.Seasons[i].PosterPath, "http") {
			show.Seasons[i].PosterPath = "https://image.tmdb.org/t/p/w500" + show.Seasons[i].PosterPath
		}
	}

	return c.JSON(http.StatusOK, show.Seasons)
}

// GET /discover/tv/:id/season/:num
func GetSeasonEpisodes(c echo.Context) error {
	// 1. Get Keys
	userID := c.Get("user_id").(uuid.UUID)
	keys, err := getUserKeys(userID)
	if err != nil || keys.TMDB == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "TMDB API key not configured"})
	}

	// 2. Parse Params
	idParam := c.Param("id")
	seasonParam := c.Param("num")
	
	tmdbID, _ := strconv.Atoi(idParam)
	if len(idParam) > 2 && idParam[:2] == "tm" {
		tmdbID, _ = strconv.Atoi(idParam[2:])
	}
	
	seasonNum, err := strconv.Atoi(seasonParam)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid season number"})
	}

	// 3. Fetch Season Details
	season, err := TmdbClient.GetSeasonDetails(keys.TMDB, tmdbID, seasonNum)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, season)
}

// Proxies the RD Unrestrict call using the User's stored token
func Unrestrict(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	keys, err := getUserKeys(userID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "user not found"})
	}
	if keys.RD == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "RealDebrid API key not configured"})
	}

	type Request struct {
		Link string `json:"link"`
	}
	var req Request
	if err := c.Bind(&req); err != nil {
		return err
	}

	link, err := RdClient.UnrestrictLink(keys.RD, req.Link)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, link)
}

func GetSystemInfo(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{
		"version": "1.0.0",
	})
}

// Helper struct
type UserKeys struct {
	RD      string
	TMDB    string
	MDBList string
}

func getUserKeys(userID uuid.UUID) (*UserKeys, error) {
	var acc models.Account
	// Select only the needed columns for speed
	err := db.DB.Select("real_debrid_key, tm_db_key, mdb_list_key").First(&acc, userID).Error
	if err != nil {
		return nil, err
	}
	return &UserKeys{
		RD:      acc.RealDebridKey,
		TMDB:    acc.TMDbKey,
		MDBList: acc.MDBListKey,
	}, nil
}

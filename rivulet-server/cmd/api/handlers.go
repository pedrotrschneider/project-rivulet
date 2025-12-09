package api

import (
	"net/http"
	"rivulet_server/internal/providers"
	"rivulet_server/internal/providers/mdblist"
	"rivulet_server/internal/providers/realdebrid"
	"rivulet_server/internal/providers/tmdb"
	"rivulet_server/internal/providers/torrentio"

	"sort"
	"strconv"

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
	userToken := c.Request().Header.Get("X-RD-Token")
	var req ResolveRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request"})
	}

	// 1. Add Magnet
	torrentID, err := RdClient.AddMagnet(userToken, req.Magnet)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed adding to cloud: " + err.Error()})
	}

	// 2. Check Info immediately
	info, err := RdClient.GetTorrentInfo(userToken, torrentID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed checking info"})
	}

	// 3. Handle "Waiting for Selection"
	// If it's a new magnet, RD pauses and asks "Which files?". We must say "All" or smart select.
	if info.Status == "waiting_files_selection" {
		err = RdClient.SelectFiles(userToken, torrentID, "all")
		if err != nil {
             return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed selecting files"})
        }
		// Re-fetch info to see the new status
		info, _ = RdClient.GetTorrentInfo(userToken, torrentID)
	}

	// 4. Decision Time
	if info.Status == "downloaded" {
		// It's Cached! Unrestrict the link immediately.
		// Usually the largest file is the movie.
		// For now, we take the first link.
		if len(info.Links) > 0 {
			unrestricted, err := RdClient.UnrestrictLink(userToken, info.Links[0])
			if err == nil {
				return c.JSON(http.StatusOK, map[string]interface{}{
					"status": "cached",
					"url":    unrestricted.Download,
					"file_id": torrentID,
				})
			}
		}
	}

	// If we are here, it is NOT cached (it's "downloading" or "queued").
	return c.JSON(http.StatusOK, map[string]string{
		"status": "downloading",
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
	apiKey := c.Request().Header.Get("X-TMDB-Key")
	if apiKey == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "missing X-TMDB-Key header"})
	}

	query := c.QueryParam("q")
	if query == "" {
		results, err := TmdbClient.GetTrending(apiKey)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		return c.JSON(http.StatusOK, results)
	}

	results, err := TmdbClient.Search(apiKey, query)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, results)
}

func GetDetails(c echo.Context) error {
	apiKey := c.Request().Header.Get("X-MDBList-Key")
	if apiKey == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "missing X-MDBList-Key header"})
	}

	id := c.Param("id")
	
	// 🔧 FIX: Get type from query params (e.g. ?type=tv)
	mediaType := c.QueryParam("type")

	// Pass it to the client
	details, err := MdbClient.GetDetails(apiKey, id, mediaType)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}
	return c.JSON(http.StatusOK, details)
}

// Proxies the RD Unrestrict call using the User's stored token
func Unrestrict(c echo.Context) error {
	// 1. Get the user's encrypted RD token from DB (Mocked for now)
	// userID := c.Get("user_id").(uuid.UUID)
	// userToken := db.GetRDToken(userID)

	// For dev testing, we'll accept it in the header temporarily,
	// or you can hardcode your own token to test.
	userToken := c.Request().Header.Get("X-RD-Token")

	type Request struct {
		Link string `json:"link"`
	}
	var req Request
	if err := c.Bind(&req); err != nil {
		return err
	}

	link, err := RdClient.UnrestrictLink(userToken, req.Link)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, link)
}

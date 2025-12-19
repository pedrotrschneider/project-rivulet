package api

import (
	"fmt"
	"net/http"
	"regexp"
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
	Magnet    string `json:"magnet"`
	Season    int    `json:"season,omitempty"`
	Episode   int    `json:"episode,omitempty"`
	FileIndex *int   `json:"file_index,omitempty"`
}

// Helper to find the file ID for a specific episode
func findFileID(files []realdebrid.File, season, episode int, fileIndex *int) (string, error) {
	// 1. If it's a movie (Season 0), return the largest file
	if season == 0 || episode == 0 {
		var largestFile realdebrid.File
		for _, f := range files {
			if f.Bytes > largestFile.Bytes {
				largestFile = f
			}
		}
		if largestFile.ID == 0 { // Check if ID is set (assuming 0 is invalid or check nil)
			return "", fmt.Errorf("no files found")
		}
		return fmt.Sprintf("%d", largestFile.ID), nil
	}

	// 2. If it's a TV Show, return the file at the specified index
	if fileIndex != nil {
		targetIdx := *fileIndex + 1

		for _, f := range files {
			if f.ID == targetIdx {
				return fmt.Sprintf("%d", f.ID), nil
			}
		}

		// Sanity check bounds
		if targetIdx >= 0 && targetIdx < len(files) {
			candidate := files[targetIdx]
			lower := strings.ToLower(candidate.Path)
			if strings.HasSuffix(lower, ".mkv") ||
				strings.HasSuffix(lower, ".mp4") ||
				strings.HasSuffix(lower, ".avi") {
				return fmt.Sprintf("%d", candidate.ID), nil
			}
		}
	}

	// If all else fails, fallback to regex approach
	pattern := fmt.Sprintf(`(?i)(S0?%d\s?E0?%d\b|\b%dx0?%d\b)`, season, episode, season, episode)
	re := regexp.MustCompile(pattern)

	for _, f := range files {
		// Only look at video files (mkv, mp4, avi) to avoid matching "S01E01.nfo"
		lowerPath := strings.ToLower(f.Path)
		if !strings.HasSuffix(lowerPath, ".mkv") &&
			!strings.HasSuffix(lowerPath, ".mp4") &&
			!strings.HasSuffix(lowerPath, ".avi") {
			continue
		}

		if re.MatchString(f.Path) {
			return fmt.Sprintf("%d", f.ID), nil
		}
	}

	return "", fmt.Errorf("episode S%02dE%02d not found in torrent", season, episode)
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
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	// 1. Add Magnet
	torrentID, err := RdClient.AddMagnet(keys.RD, req.Magnet)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed adding to cloud: " + err.Error()})
	}

	// 2. Check Info
	info, err := RdClient.GetTorrentInfo(keys.RD, torrentID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed checking info"})
	}

	// 3. Select Specific File (The "Stremio" Logic)
	targetFileID, err := findFileID(info.Files, req.Season, req.Episode, req.FileIndex)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	// 4. Send Selection to RD (If needed)
	// If status is "waiting_files_selection", we MUST select this specific file to start the process/get the link.
	if info.Status == "waiting_files_selection" {
		err = RdClient.SelectFiles(keys.RD, torrentID, targetFileID)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed selecting file"})
		}
		// Refresh info to get the links
		info, _ = RdClient.GetTorrentInfo(keys.RD, torrentID)
	}

	// 5. Find the Unrestrict Link

	if info.Status == "downloaded" {
		targetLink := ""
		if len(info.Links) == 1 {
			targetLink = info.Links[0]
		} else {
			if len(info.Links) > 0 {
				targetLink = info.Links[0]
			}
		}

		if targetLink != "" {
			unrestricted, err := RdClient.UnrestrictLink(keys.RD, targetLink)
			if err == nil {
				// Helper to parse string ID back to int for frontend consistency
				// User note: RD IDs are 1-based, but we deal with 0-based indexes.
				// We must return ID - 1 so that when it comes back, we add 1 to get the ID again.
				fIdx, _ := strconv.Atoi(targetFileID)
				return c.JSON(http.StatusOK, map[string]interface{}{
					"status":     "cached",
					"url":        unrestricted.Download,
					"file_id":    torrentID,
					"file_index": fIdx - 1,
				})
			}
		}
	}

	return c.JSON(http.StatusOK, map[string]string{
		"status":  "downloading",
		"message": fmt.Sprintf("Episode S%02dE%02d added to cloud.", req.Season, req.Episode),
		"file_id": torrentID,
	})
}

func getQualityRank(quality string) int {
	q := strings.ToLower(quality)
	if strings.Contains(q, "4k") || strings.Contains(q, "2160p") {
		return 40
	}
	if strings.Contains(q, "1080p") {
		return 30
	}
	if strings.Contains(q, "720p") {
		return 20
	}
	if strings.Contains(q, "480p") {
		return 10
	}
	return 0 // Unknown
}

// GET /stream/scrape?external_id=imdb:tt123&type=movie&season=1&episode=1
func ScrapeStreams(c echo.Context) error {
	userID := c.Get("user_id").(uuid.UUID)
	keys, err := getUserKeys(userID)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "user not found"})
	}
	if keys.RD == "" {
		return c.JSON(http.StatusConflict, map[string]string{"error": "RealDebrid API key not configured"})
	}

	externalID := c.QueryParam("external_id") // e.g. "imdb:tt1375666"
	mediaType := c.QueryParam("type")         // "movie" or "show"

	if externalID == "" || mediaType == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "missing params"})
	}

	// Parse ID
	imdbID := externalID
	isImdb := false
	if len(externalID) > 5 && externalID[:5] == "imdb:" {
		imdbID = externalID[5:]
		isImdb = true
	} else if len(externalID) > 2 && externalID[:2] == "tt" {
		isImdb = true
	}

	// If NOT a clear IMDB ID, try to resolve via MDBList
	if !isImdb && keys.MDBList != "" {
		details, err := MdbClient.GetDetails(keys.MDBList, externalID, mediaType)
		if err == nil && details.ImdbID != "" {
			imdbID = details.ImdbID
		} else {
			// Log fallback or error?
			// fmt.Println("Failed to resolve ID:", externalID, err)
		}
	}

	// Parse Season/Episode
	season, _ := strconv.Atoi(c.QueryParam("season"))
	episode, _ := strconv.Atoi(c.QueryParam("episode"))

	// 1. Fetch Streams (Concurrent)
	streams := ScraperManager.ScrapeAll(mediaType, imdbID, keys.RD, season, episode)

	if len(streams) == 0 {
		return c.JSON(http.StatusOK, []interface{}{})
	}

	// 3. Smart Sort: Quality > Seeds > Size
	sort.Slice(streams, func(i, j int) bool {
		// A. Quality Rank (4k > 1080p)
		rankI := getQualityRank(streams[i].Quality)
		rankJ := getQualityRank(streams[j].Quality)
		if rankI != rankJ {
			return rankI > rankJ
		}

		// B. Seeders (High availability beats low)
		if streams[i].Seeds != streams[j].Seeds {
			return streams[i].Seeds > streams[j].Seeds
		}

		// C. Size (Bigger usually means better bitrate within same resolution)
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

	// Set has next season
	for i := range show.Seasons {
		if i < len(show.Seasons)-1 {
			show.Seasons[i].HasNextSeason = true
		} else {
			show.Seasons[i].HasNextSeason = false
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

	for i := range season.Episodes {
		if i < len(season.Episodes)-1 {
			season.Episodes[i].IsSeasonFinale = false
		} else {
			season.Episodes[i].IsSeasonFinale = true
		}
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

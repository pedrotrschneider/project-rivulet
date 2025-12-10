package providers

type Stream struct {
	Title       string `json:"title"`
	Size        int64  `json:"size"` // In Bytes
	Hash        string `json:"hash"`
	Magnet      string `json:"magnet"`
	Quality     string `json:"quality"` // "4k", "1080p"
	Seeds       int    `json:"seeds"`
	Source      string `json:"source"` // "torrentio", "knightcrawler"
	FileIndex   *int   `json:"file_index,omitempty"`
}

type Scraper interface {
	Name() string
	// Scrape fetches streams. type="movie"|"series", id="tt123", season/ep for shows
	Scrape(mediaType, imdbID string, season, episode int) ([]*Stream, error)
}
package providers

import (
	"log"
	"sync"
)

type Manager struct {
	Scrapers []Scraper
}

func NewManager(scrapers ...Scraper) *Manager {
	return &Manager{
		Scrapers: scrapers,
	}
}

// ScrapeAll queries all providers in parallel and merges results
func (m *Manager) ScrapeAll(mediaType, imdbID, rdKey string, season, episode int) []*Stream {
	var wg sync.WaitGroup
	resultsChan := make(chan []*Stream, len(m.Scrapers))

	// 1. Launch Goroutines
	for _, s := range m.Scrapers {
		wg.Add(1)
		go func(scraper Scraper) {
			defer wg.Done()
			
			// Add timeout/context logic here in production
			streams, err := scraper.Scrape(mediaType, imdbID, rdKey, season, episode)
			if err != nil {
				log.Printf("⚠️ [%s] Scrape failed: %v", scraper.Name(), err)
				return
			}
			resultsChan <- streams
		}(s)
	}

	// 2. Wait and Close
	go func() {
		wg.Wait()
		close(resultsChan)
	}()

	// 3. Aggregate
	var allStreams []*Stream
	// Use a map to deduplicate by Hash if multiple providers return the same torrent
	seenHashes := make(map[string]bool)

	for streams := range resultsChan {
		for _, s := range streams {
			if !seenHashes[s.Hash] {
				seenHashes[s.Hash] = true
				allStreams = append(allStreams, s)
			}
		}
	}

	return allStreams
}
package adapters

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// TikaClient handles communication with Apache Tika server
type TikaClient struct {
	baseURL string
	client  *http.Client
}

// NewTikaClient creates a new Tika client
func NewTikaClient(baseURL string) *TikaClient {
	if baseURL == "" {
		baseURL = getTikaURL()
	}

	return &TikaClient{
		baseURL: baseURL,
		client: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

// ExtractText extracts text from a PDF file using Tika
func (t *TikaClient) ExtractText(filePath string) (string, error) {
	// Open the file
	file, err := os.Open(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	// Create request with binary data
	url := fmt.Sprintf("%s/tika", t.baseURL)
	req, err := http.NewRequest("PUT", url, file)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Accept", "text/plain")
	req.Header.Set("Content-Type", "application/pdf")

	// Send request
	resp, err := t.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("tika server returned status: %d", resp.StatusCode)
	}

	// Read response
	text, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	return string(text), nil
}

// getTikaURL returns Tika URL from environment or default
func getTikaURL() string {
	url := os.Getenv("TIKA_URL")
	if url == "" {
		return "http://localhost:9998"
	}
	return url
}

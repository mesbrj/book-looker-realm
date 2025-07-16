package core

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// PDFJob represents a job to process a PDF file
type PDFJob struct {
	ID       string `json:"id"`
	FilePath string `json:"file_path"`
	FileName string `json:"file_name"`
}

// PDFProcessor handles PDF file selection and validation
type PDFProcessor struct{}

// NewPDFProcessor creates a new PDF processor
func NewPDFProcessor() *PDFProcessor {
	return &PDFProcessor{}
}

// CreateJob creates a PDF job from the given file path
func (p *PDFProcessor) CreateJob(filePath string) (*PDFJob, error) {
	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return nil, fmt.Errorf("file does not exist: %s", filePath)
	}

	// Check if it's a PDF file
	if filepath.Ext(filePath) != ".pdf" {
		return nil, fmt.Errorf("file is not a PDF: %s", filePath)
	}

	// Get absolute path
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to get absolute path: %w", err)
	}

	job := &PDFJob{
		ID:       generateJobID(),
		FilePath: absPath,
		FileName: filepath.Base(absPath),
	}

	return job, nil
}

// ToJSON converts the PDF job to JSON
func (j *PDFJob) ToJSON() ([]byte, error) {
	return json.Marshal(j)
}

// FromJSON creates a PDF job from JSON
func FromJSON(data []byte) (*PDFJob, error) {
	var job PDFJob
	err := json.Unmarshal(data, &job)
	return &job, err
}

// generateJobID generates a unique job ID
func generateJobID() string {
	// Generate random bytes
	bytes := make([]byte, 8)
	rand.Read(bytes)

	// Create ID with timestamp and random component
	timestamp := time.Now().Unix()
	return fmt.Sprintf("job_%d_%s", timestamp, hex.EncodeToString(bytes)[:8])
}

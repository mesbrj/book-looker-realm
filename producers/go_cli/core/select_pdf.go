package core

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// PDFJob represents a job to process multiple PDF files
type PDFJob struct {
	ID             string   `json:"id"`
	JobCreateEpoch int64    `json:"create_timestamp"`
	FilePathList   []string `json:"file_path_list"`
	FileNameList   []string `json:"file_name_list"`
	OutputPath     string   `json:"output_path"`
}

// PDFProcessor handles PDF file selection and validation
type PDFProcessor struct{}

// NewPDFProcessor creates a new PDF processor
func NewPDFProcessor() *PDFProcessor {
	return &PDFProcessor{}
}

// CreateJobFromPaths creates a PDF job from the given file paths and output path
func (p *PDFProcessor) CreateJobFromPaths(filePathsStr, outputPath string) (*PDFJob, error) {
	// Split comma-separated paths
	paths := strings.Split(filePathsStr, ",")
	var filePathList []string
	var fileNameList []string

	for _, path := range paths {
		// Trim whitespace
		path = strings.TrimSpace(path)
		if path == "" {
			continue
		}

		// Check if file exists
		if _, err := os.Stat(path); os.IsNotExist(err) {
			return nil, fmt.Errorf("file does not exist: %s", path)
		}

		// Check if it's a PDF file
		if filepath.Ext(path) != ".pdf" {
			return nil, fmt.Errorf("file is not a PDF: %s", path)
		}

		// Get absolute path
		absPath, err := filepath.Abs(path)
		if err != nil {
			return nil, fmt.Errorf("failed to get absolute path for %s: %w", path, err)
		}

		filePathList = append(filePathList, absPath)
		fileNameList = append(fileNameList, filepath.Base(absPath))
	}

	if len(filePathList) == 0 {
		return nil, fmt.Errorf("no valid PDF files provided")
	}

	job := &PDFJob{
		ID:             generateJobID(),
		JobCreateEpoch: time.Now().Unix(),
		FilePathList:   filePathList,
		FileNameList:   fileNameList,
		OutputPath:     outputPath,
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

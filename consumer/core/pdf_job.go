package core

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"consumer/adapters"
)

// PDFJob represents a job to process multiple PDF files
type PDFJob struct {
	ID             string   `json:"id"`
	JobCreateEpoch int64    `json:"create_timestamp"`
	FilePathList   []string `json:"file_path_list"`
	FileNameList   []string `json:"file_name_list"`
	OutputPath     string   `json:"output_path"`
}

// FromJSON creates a PDF job from JSON
func FromJSON(data []byte) (*PDFJob, error) {
	var job PDFJob
	err := json.Unmarshal(data, &job)
	return &job, err
}

// MessageHandler handles incoming PDF job messages
type MessageHandler struct {
	tikaClient *adapters.TikaClient
	semaphore  chan struct{}  // Limits concurrent Tika requests
	wg         sync.WaitGroup // Tracks ongoing extractions
}

// NewMessageHandler creates a new message handler
func NewMessageHandler(tikaClient *adapters.TikaClient) *MessageHandler {
	return &MessageHandler{
		tikaClient: tikaClient,
		semaphore:  make(chan struct{}, 3), // Allow max 3 concurrent Tika requests
	}
}

// extractTextAsync performs text extraction asynchronously using Tika for a single file
func (h *MessageHandler) extractTextAsync(jobID, filePath, fileName, outputPath string) {
	defer h.wg.Done()

	// Acquire semaphore to limit concurrent requests
	h.semaphore <- struct{}{}
	defer func() { <-h.semaphore }()

	log.Printf("Starting text extraction for job: %s (file: %s)", jobID, fileName)

	// Extract text using Tika
	text, err := h.tikaClient.ExtractText(filePath)
	if err != nil {
		log.Printf("Failed to extract text from %s: %v", fileName, err)
		return
	}

	log.Printf("Successfully extracted text from %s (%d characters)", fileName, len(text))

	// Save text to file
	if err := h.saveTextToFile(text, fileName, outputPath); err != nil {
		log.Printf("Failed to save text file for %s: %v", fileName, err)
		return
	}

	// Log preview for debugging
	if len(text) > 200 {
		log.Printf("Text preview: %s...", text[:200])
	} else {
		log.Printf("Full text: %s", text)
	}
}

// saveTextToFile saves extracted text to a file with .txt extension
func (h *MessageHandler) saveTextToFile(text, fileName, outputPath string) error {
	// Create output directory if it doesn't exist
	if err := os.MkdirAll(outputPath, 0755); err != nil {
		return fmt.Errorf("failed to create output directory %s: %w", outputPath, err)
	}

	// Generate output filename: replace .pdf with .txt
	baseFileName := strings.TrimSuffix(fileName, filepath.Ext(fileName))
	outputFileName := baseFileName + ".txt"
	outputFilePath := filepath.Join(outputPath, outputFileName)

	// Write text to file
	if err := os.WriteFile(outputFilePath, []byte(text), 0644); err != nil {
		return fmt.Errorf("failed to write text file %s: %w", outputFilePath, err)
	}

	log.Printf("Successfully saved text to file: %s", outputFilePath)
	return nil
}

// HandlePDFJob processes a PDF job message with multiple files asynchronously
func (h *MessageHandler) HandlePDFJob(messageData []byte) error {
	// Parse the job from JSON
	job, err := FromJSON(messageData)
	if err != nil {
		return err
	}

	// Validate that file lists have the same length
	if len(job.FilePathList) != len(job.FileNameList) {
		return fmt.Errorf("file path list and file name list have different lengths for job %s", job.ID)
	}

	log.Printf("Processing PDF job: %s with %d files", job.ID, len(job.FilePathList))

	// Start async text extraction for each file
	for i, filePath := range job.FilePathList {
		fileName := job.FileNameList[i]
		h.wg.Add(1)
		go h.extractTextAsync(job.ID, filePath, fileName, job.OutputPath)
	}

	// Return immediately - don't wait for text extraction to complete
	log.Printf("PDF job %s queued for text extraction (%d files)", job.ID, len(job.FilePathList))
	return nil
}

// WaitForExtractions waits for all ongoing text extractions to complete
func (h *MessageHandler) WaitForExtractions() {
	h.wg.Wait()
	log.Println("All text extractions completed")
}

// StartConsumer starts the Kafka consumer
func StartConsumer(ctx context.Context, brokers []string, topic string, groupID string, tikaClient *adapters.TikaClient) error {
	consumer, err := adapters.NewKafkaConsumer(brokers, topic, groupID)
	if err != nil {
		return fmt.Errorf("failed to create Kafka consumer: %v", err)
	}
	defer consumer.Close()

	handler := NewMessageHandler(tikaClient)

	// Ensure all extractions complete when shutting down
	defer handler.WaitForExtractions()

	log.Printf("Starting consumer for topic: %s", topic)
	return consumer.ConsumeMessages(ctx, handler.HandlePDFJob)
}

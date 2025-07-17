package core

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"

	"consumer/adapters"
)

// PDFJob represents a job to process multiple PDF files
type PDFJob struct {
	ID             string   `json:"id"`
	JobCreateEpoch int64    `json:"create_timestamp"`
	FilePathList   []string `json:"file_path_list"`
	FileNameList   []string `json:"file_name_list"`
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
func (h *MessageHandler) extractTextAsync(jobID, filePath, fileName string) {
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

	// In a real application, you would save this text to a database or file
	// For now, we'll just log the first 200 characters
	if len(text) > 200 {
		log.Printf("Text preview: %s...", text[:200])
	} else {
		log.Printf("Full text: %s", text)
	}
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
		go h.extractTextAsync(job.ID, filePath, fileName)
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

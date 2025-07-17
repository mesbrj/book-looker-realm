package core

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"

	"consumer/adapters"
)

// PDFJob represents a job to process a PDF file
type PDFJob struct {
	ID       string `json:"id"`
	FilePath string `json:"file_path"`
	FileName string `json:"file_name"`
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

// extractTextAsync performs text extraction asynchronously using Tika
func (h *MessageHandler) extractTextAsync(job *PDFJob) {
	defer h.wg.Done()

	// Acquire semaphore to limit concurrent requests
	h.semaphore <- struct{}{}
	defer func() { <-h.semaphore }()

	log.Printf("Starting text extraction for job: %s (file: %s)", job.ID, job.FileName)

	// Extract text using Tika
	text, err := h.tikaClient.ExtractText(job.FilePath)
	if err != nil {
		log.Printf("Failed to extract text from %s: %v", job.FileName, err)
		return
	}

	log.Printf("Successfully extracted text from %s (%d characters)", job.FileName, len(text))

	// In a real application, you would save this text to a database or file
	// For now, we'll just log the first 200 characters
	if len(text) > 200 {
		log.Printf("Text preview: %s...", text[:200])
	} else {
		log.Printf("Full text: %s", text)
	}
}

// HandlePDFJob processes a PDF job message asynchronously
func (h *MessageHandler) HandlePDFJob(messageData []byte) error {
	// Parse the job from JSON
	job, err := FromJSON(messageData)
	if err != nil {
		return err
	}

	log.Printf("Processing PDF job: %s (file: %s)", job.ID, job.FileName)

	// Start async text extraction
	h.wg.Add(1)
	go h.extractTextAsync(job)

	// Return immediately - don't wait for text extraction to complete
	log.Printf("PDF job %s queued for text extraction", job.ID)
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

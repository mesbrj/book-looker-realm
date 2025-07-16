package core

import (
	"context"
	"encoding/json"
	"log"

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
}

// NewMessageHandler creates a new message handler
func NewMessageHandler(tikaClient *adapters.TikaClient) *MessageHandler {
	return &MessageHandler{
		tikaClient: tikaClient,
	}
}

// HandlePDFJob processes a PDF job message
func (h *MessageHandler) HandlePDFJob(messageData []byte) error {
	// Parse the job from JSON
	job, err := FromJSON(messageData)
	if err != nil {
		return err
	}

	log.Printf("Processing PDF job: %s (file: %s)", job.ID, job.FileName)

	// Extract text using Tika
	text, err := h.tikaClient.ExtractText(job.FilePath)
	if err != nil {
		return err
	}

	log.Printf("Successfully extracted text from %s (%d characters)", job.FileName, len(text))

	// In a real application, you would save this text to a database or file
	// For now, we'll just log the first 200 characters
	if len(text) > 200 {
		log.Printf("Text preview: %s...", text[:200])
	} else {
		log.Printf("Full text: %s", text)
	}

	return nil
}

// StartConsumer starts the Kafka consumer
func StartConsumer(ctx context.Context, brokers []string, topic string, groupID string, tikaClient *adapters.TikaClient) error {
	consumer := adapters.NewKafkaConsumer(brokers, topic, groupID)
	defer consumer.Close()

	handler := NewMessageHandler(tikaClient)

	log.Printf("Starting consumer for topic: %s", topic)
	return consumer.ConsumeMessages(ctx, handler.HandlePDFJob)
}

package adapters

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/segmentio/kafka-go"
)

// KafkaProducer interface defines the producer behavior
type KafkaProducer interface {
	SendMessage(ctx context.Context, topic string, key string, value []byte) error
	Close() error
}

// KafkaProducerImpl implements the KafkaProducer interface
// NewKafkaProducer creates a new Kafka producer
type KafkaProducerImpl struct {
	writer *kafka.Writer
}

func NewKafkaProducer(brokers []string, topic string) *KafkaProducerImpl {
	log.Printf("Creating Kafka producer for brokers: %v, topic: %s", brokers, topic)

	writer := &kafka.Writer{
		Addr:         kafka.TCP(brokers...),
		Topic:        topic,
		Balancer:     &kafka.LeastBytes{},
		WriteTimeout: 30 * time.Second,
		ReadTimeout:  30 * time.Second,
		RequiredAcks: kafka.RequireOne,
		Async:        true,
	}
	return &KafkaProducerImpl{
		writer: writer,
	}
}

// SendMessage sends a message to Kafka with retry logic
func (p *KafkaProducerImpl) SendMessage(ctx context.Context, topic string, key string, value []byte) error {
	message := kafka.Message{
		Key:   []byte(key),
		Value: value,
	}

	// Add retry logic for connection issues
	maxRetries := 3
	for attempt := 1; attempt <= maxRetries; attempt++ {
		err := p.writer.WriteMessages(ctx, message)
		if err == nil {
			log.Printf("Message sent successfully: key=%s", key)
			return nil
		}

		log.Printf("Attempt %d/%d failed to send message: %v", attempt, maxRetries, err)

		if attempt < maxRetries {
			// Wait before retrying
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(2 * time.Second):
				continue
			}
		}
	}

	return fmt.Errorf("failed to send message after %d attempts", maxRetries)
}

// Close closes the producer
func (p *KafkaProducerImpl) Close() error {
	return p.writer.Close()
}

// GetKafkaBrokers returns Kafka brokers from environment or default
func GetKafkaBrokers() []string {
	brokers := os.Getenv("KAFKA_BROKERS")
	if brokers == "" {
		return []string{"localhost:9092"}
	}
	return []string{brokers}
}

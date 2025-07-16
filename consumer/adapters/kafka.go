package adapters

import (
	"context"
	"log"
	"os"

	"github.com/segmentio/kafka-go"
)

// KafkaConsumer handles consuming messages from Kafka
type KafkaConsumer struct {
	reader *kafka.Reader
}

// NewKafkaConsumer creates a new Kafka consumer
func NewKafkaConsumer(brokers []string, topic string, groupID string) *KafkaConsumer {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:  brokers,
		Topic:    topic,
		GroupID:  groupID,
		MinBytes: 10e3, // 10KB
		MaxBytes: 10e6, // 10MB
	})

	return &KafkaConsumer{
		reader: reader,
	}
}

// ConsumeMessages consumes messages from Kafka
func (c *KafkaConsumer) ConsumeMessages(ctx context.Context, handler func([]byte) error) error {
	for {
		select {
		case <-ctx.Done():
			log.Println("Context cancelled, stopping message consumption")
			return ctx.Err()
		default:
			// Set a timeout for ReadMessage to avoid blocking indefinitely
			message, err := c.reader.ReadMessage(ctx)
			if err != nil {
				// Check if context was cancelled
				if ctx.Err() != nil {
					return ctx.Err()
				}
				log.Printf("Failed to read message: %v", err)
				// Continue to try reading more messages
				continue
			}

			log.Printf("Received message: key=%s", string(message.Key))

			if err := handler(message.Value); err != nil {
				log.Printf("Failed to handle message: %v", err)
				// In production, you might want to implement dead letter queue
				continue
			}
		}
	}
}

// Close closes the consumer
func (c *KafkaConsumer) Close() error {
	return c.reader.Close()
}

// GetKafkaBrokers returns Kafka brokers from environment or default
func GetKafkaBrokers() []string {
	brokers := os.Getenv("KAFKA_BROKERS")
	if brokers == "" {
		return []string{"localhost:9092"}
	}
	return []string{brokers}
}

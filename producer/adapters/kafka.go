package adapters

import (
	"context"
	"fmt"
	"log"
	"os"

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
	writer := &kafka.Writer{
		Addr:     kafka.TCP(brokers...),
		Topic:    topic,
		Balancer: &kafka.LeastBytes{},
	}
	return &KafkaProducerImpl{
		writer: writer,
	}
}

// SendMessage sends a message to Kafka
func (p *KafkaProducerImpl) SendMessage(ctx context.Context, topic string, key string, value []byte) error {
	message := kafka.Message{
		Key:   []byte(key),
		Value: value,
	}

	err := p.writer.WriteMessages(ctx, message)
	if err != nil {
		return fmt.Errorf("failed to write message: %w", err)
	}

	log.Printf("Message sent successfully: key=%s", key)
	return nil
}

// Close closes the producer
func (p *KafkaProducerImpl) Close() error {
	return p.writer.Close()
}

// GetKafkaBrokers returns Kafka brokers from environment or default
func GetKafkaBrokers() []string {
	brokers := os.Getenv("KAFKA_BROKERS")
	if brokers == "" {
		return []string{"localhost:9094"}
	}
	return []string{brokers}
}

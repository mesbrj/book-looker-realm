package adapters

import (
	"context"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"github.com/IBM/sarama"
)

// KafkaConsumer handles consuming messages from Kafka
type KafkaConsumer struct {
	consumer sarama.ConsumerGroup
	ready    chan bool
}

// Sarama Consumer Group Interface
// Consumer represents a Sarama consumer group consumer
type Consumer struct {
	ready   chan bool
	handler func([]byte) error
}

// Sarama Consumer Group Interface
// Setup is run at the beginning of a new session, before ConsumeClaim
func (consumer *Consumer) Setup(sarama.ConsumerGroupSession) error {
	close(consumer.ready)
	return nil
}

// Sarama Consumer Group Interface
// Cleanup is run at the end of a session, once all ConsumeClaim goroutines have exited
func (consumer *Consumer) Cleanup(sarama.ConsumerGroupSession) error {
	return nil
}

// Sarama Consumer Group Interface
// ConsumeClaim must start a consumer loop of ConsumerGroupClaim's Messages().
func (consumer *Consumer) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for {
		select {
		case message := <-claim.Messages():
			if message == nil {
				return nil
			}

			log.Printf("Received message: key=%s, partition=%d, offset=%d",
				string(message.Key), message.Partition, message.Offset)

			if err := consumer.handler(message.Value); err != nil {
				log.Printf("Failed to handle message: %v", err)
			} else {
				log.Printf("Successfully processed message at offset %d", message.Offset)
			}

			// Mark the message as processed
			session.MarkMessage(message, "")

		case <-session.Context().Done():
			return nil
		}
	}
}

// NewKafkaConsumer creates a new Kafka consumer
func NewKafkaConsumer(brokers []string, topic string, groupID string) (*KafkaConsumer, error) {
	config := sarama.NewConfig()
	config.Consumer.Group.Rebalance.Strategy = sarama.BalanceStrategyRoundRobin
	config.Consumer.Offsets.Initial = sarama.OffsetOldest
	config.Version = sarama.V2_6_0_0

	consumer, err := sarama.NewConsumerGroup(brokers, groupID, config)
	if err != nil {
		return nil, err
	}

	return &KafkaConsumer{
		consumer: consumer,
		ready:    make(chan bool),
	}, nil
}

// ConsumeMessages consumes messages from Kafka
func (c *KafkaConsumer) ConsumeMessages(ctx context.Context, handler func([]byte) error) error {
	log.Println("Starting message consumption...")

	consumer := &Consumer{
		ready:   c.ready,
		handler: handler,
	}

	wg := &sync.WaitGroup{}
	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			if err := c.consumer.Consume(ctx, []string{"pdf-jobs"}, consumer); err != nil {
				log.Printf("Error from consumer: %v", err)
				return
			}
			if ctx.Err() != nil {
				return
			}
		}
	}()

	<-consumer.ready
	log.Println("Sarama consumer up and running!...")

	sigterm := make(chan os.Signal, 1)
	signal.Notify(sigterm, syscall.SIGINT, syscall.SIGTERM)

	select {
	case <-ctx.Done():
		log.Println("Context cancelled")
	case <-sigterm:
		log.Println("Terminating: via signal")
	}

	wg.Wait()
	return nil
}

// Close closes the consumer
func (c *KafkaConsumer) Close() error {
	return c.consumer.Close()
}

// GetKafkaBrokers returns Kafka brokers from environment or default
func GetKafkaBrokers() []string {
	brokers := os.Getenv("KAFKA_BROKERS")
	if brokers == "" {
		return []string{"localhost:9094"}
	}
	return []string{brokers}
}

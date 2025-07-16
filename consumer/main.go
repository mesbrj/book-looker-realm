package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"consumer/adapters"
	"consumer/core"
)

const (
	kafkaTopic = "pdf-jobs"
	groupID    = "pdf-consumer-group"
)

func main() {
	// Create context that can be cancelled
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("Shutting down consumer...")
		cancel()
	}()

	// Create Tika client
	tikaClient := adapters.NewTikaClient("")

	// Get Kafka brokers
	brokers := adapters.GetKafkaBrokers()

	// Start consumer
	log.Println("Starting PDF consumer...")
	err := core.StartConsumer(ctx, brokers, kafkaTopic, groupID, tikaClient)
	if err != nil && err != context.Canceled {
		log.Fatalf("Consumer error: %v", err)
	}

	log.Println("Consumer stopped")
}

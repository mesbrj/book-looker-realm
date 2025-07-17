package main

import (
	"context"
	"log"

	"producer/adapters"
	"producer/core"
)

const (
	kafkaTopic = "pdf-jobs"
)

func main() {
	// Parse CLI arguments
	cli := adapters.NewCLIAdapter()
	filePathsStr, outputPath, err := cli.ParseArgs()
	if err != nil {
		log.Fatalf("CLI error: %v", err)
	}

	// Create PDF processor
	processor := core.NewPDFProcessor()
	job, err := processor.CreateJobFromPaths(filePathsStr, outputPath)
	if err != nil {
		log.Fatalf("Failed to create PDF job: %v", err)
	}

	// Convert job to JSON
	jobData, err := job.ToJSON()
	if err != nil {
		log.Fatalf("Failed to marshal job: %v", err)
	}

	// Create Kafka producer
	producer := adapters.NewKafkaProducer(
		adapters.GetKafkaBrokers(),
		kafkaTopic)
	defer producer.Close()

	// Send message to Kafka
	ctx := context.Background()
	err = producer.SendMessage(ctx, kafkaTopic, job.ID, jobData)
	if err != nil {
		log.Fatalf("Failed to send message: %v", err)
	}

	log.Printf("Successfully sent PDF job: %s (%d files: %v) -> output: %s", job.ID, len(job.FileNameList), job.FileNameList, job.OutputPath)
}

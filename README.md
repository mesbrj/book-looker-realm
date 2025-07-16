# PDF Text Extraction Pipeline

This project implements a PDF text extraction pipeline using Apache Kafka and Apache Tika.

## Architecture

- **Producer**: Receives PDF file paths via CLI and sends jobs to Kafka topic
- **Consumer**: Processes Kafka messages and extracts text (from PDF) using Apache Tika
- **Kafka**: Message broker for job queue
- **Tika**: Text extraction service

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Go 1.21+ (for local development)

### Running with Docker Compose

1. **Start all services:**
```bash
docker-compose up -d
```

2. **Wait for services to be ready** (approximately 30 seconds)

3. **Create a test PDF** (put sample PDF files in `test_pdfs/` directory)

4. **Send a PDF job:**
```bash
# Using the producer container
docker-compose exec producer ./producer /app/pdfs/sample.pdf

# Or if running locally
cd producer
go run main.go /path/to/your/file.pdf
```

5. **Check consumer logs:**
```bash
docker-compose logs -f consumer
```

### Local Development

1. **Start infrastructure services only:**
```bash
docker-compose up -d kafka tika
```

2. **Run producer locally:**
```bash
cd producer
go mod tidy
go run main.go /path/to/pdf/file.pdf
```

3. **Run consumer locally:**
```bash
cd consumer
go mod tidy
go run main.go
```

## Environment Variables

### Producer
- `KAFKA_BROKERS`: Kafka broker addresses (default: `localhost:9092`)

### Consumer
- `KAFKA_BROKERS`: Kafka broker addresses (default: `localhost:9092`)
- `TIKA_URL`: Tika server URL (default: `http://localhost:9998`)

## API Endpoints

### Tika Server
- **Extract Text**: `PUT http://localhost:9998/tika`
  - Content-Type: `multipart/form-data`
  - Accept: `text/plain`

### Kafka Topics
- **pdf-jobs**: Queue for PDF processing jobs

## Message Format

PDF jobs are sent as JSON messages:

```json
{
  "id": "job_12345",
  "file_path": "/app/pdfs/document.pdf",
  "file_name": "document.pdf"
}
```

## Troubleshooting

### Useful Commands

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f [service_name]

# Clean restart
docker-compose down && docker-compose up -d

# Kafka topic inspection
docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

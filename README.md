# Text and Metadata (file archive and contents) Detection and Extraction Pipeline

This project implements a text and metadata (file/contents) extraction pipeline using Apache Kafka and Apache Tika.

- **Publisher**: Receives file paths via CLI and sends job messages to Kafka topic.
- **Subscriber**: Processes Kafka messages and extracts text (from files) using Apache Tika (only PDF file type at this moment).
- **Kafka**: Message broker for job messages queue.
- **Tika**: Text extraction service

### Prerequisites
- Podman / Docker and Docker / Podman Compose
*Tested with **Podman Compose***
- Go

### Running with Docker Compose

```bash
docker-compose up -d
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

## Tika Server
- **Extract Text from file (Tika detects the file type, including images using OCR)**: `POST http://localhost:9998/tika/form`
  - Content-Type: `multipart/form-data`
  - Accept: `text/plain`

- **Get Metadata (file and contents) from file**: `POST http://localhost:9998/meta/form`
  - Content-Type: `multipart/form-data`
  - Accept: `application/json`, `application/rdf+xml`, `text/csv`, `text/plain`

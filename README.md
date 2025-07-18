# Text and Metadata (file archive and contents) Detection and Extraction Pipeline

This project implements a text and metadata (file/contents) extraction pipeline using Apache Kafka and Apache Tika.

- **Publisher**: Receives file paths via CLI and sends job messages to Kafka topic.
- **Subscriber**: Processes Kafka messages and extracts text (from files) using Apache Tika (only PDF file type at this moment).
- **Kafka**: Message broker for job messages queue.
- **Tika**: Text extraction service

## Roadmap
- [ ] Release all Tika capabilities (Go Subscriber app). Including the translation capabilities, portuguese to spanish for example (Lingo24/Microsoft/Google).
- [ ] Use MinIO as centralized storage for files and Tika outputs.
- [ ] MinIO Bucket notification using the Go Publisher app as target (webhook).

### Prerequisites
- Podman / Docker and Docker / Podman Compose

*Tested with **Podman and podman-compose***
- Go

### Running with Docker Compose

**Start the infrastructure and create Kafka topic:**
```bash
docker-compose up -d kafka tika
./kafka-topics.sh --create --topic pdf-jobs --bootstrap-server localhost:9094
```

**Start the consumer services:**
```bash
docker-compose up -d consumer
```

**Send PDF files for processing:**
```bash
docker-compose run --rm producer ./producer "/app/samples/osdc_Lua_20230211.pdf, /app/samples/osdc_Pragmatic-systemd_2023.03.15.pdf, /app/samples/OSDC_webassembly_20230209.pdf" "/app/samples/tika_output_tests"
# Send multiple jobs:
for i in {1..5}; do echo "Sending job $i"; docker-compose run --rm producer ./producer "/app/samples/osdc_Lua_20230211.pdf, /app/samples/osdc_Pragmatic-systemd_2023.03.15.pdf, /app/samples/OSDC_webassembly_20230209.pdf" "/app/samples/tika_output_tests"; done
```

**View consumer logs:**
```bash
docker-compose logs consumer --tail 20
```

### Local Development

1. **Start infrastructure services only:**
```bash
docker-compose up -d kafka tika
./kafka-topics.sh --create --topic pdf-jobs --bootstrap-server localhost:9094
```

2. **Run producer locally:**
```bash
cd producer
go mod tidy
go run main.go "../samples/osdc_Lua_20230211.pdf" "../samples/tika_output_tests"
```

3. **Run consumer locally:**
```bash
cd consumer
go mod tidy
go run main.go
```

## Tika Server
[**Documentation**](https://cwiki.apache.org/confluence/display/TIKA/TikaServer)

- **Extract Text from file (Tika detects the file type, including images using OCR)**: `POST http://localhost:9998/tika/form`
  - Content-Type: `multipart/form-data`
  - Accept: `text/plain`

- **Get Metadata (file and contents) from file**: `POST http://localhost:9998/meta/form`
  - Content-Type: `multipart/form-data`
  - Accept: `application/json`, `application/rdf+xml`, `text/csv`, `text/plain`

*Sample PDF files licensed under*: [**Creative Commons Attribution Share-alike 4.0**](https://creativecommons.org/licenses/by-sa/4.0/deed.en)
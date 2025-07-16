.PHONY: build start dev stop clean test help

# Build both producer and consumer
build:
	@echo "Building producer..."
	cd producer && go build -o producer main.go
	@echo "Building consumer..."
	cd consumer && go build -o consumer main.go
	@echo "Build complete!"

# Start all services with Docker Compose
start:
	@echo "Starting all services..."
	docker-compose up -d

# Start only infrastructure for local development
dev_infra:
	@echo "Starting infrastructure services..."
	docker-compose up -d kafka tika

# Start application services
dev_apps:
	@echo "Starting application services..."
	docker-compose up -d producer consumer

# Stop all services
stop:
	docker-compose down

# Clean everything (containers, images, volumes)
clean:
	docker-compose down -v --rmi all

# Run producer locally (requires infrastructure to be running)
run-producer:
	@if [ -z "$(FILE)" ]; then echo "Usage: make run-producer FILE=/path/to/pdf"; exit 1; fi
	cd producer && go run main.go $(FILE)

# Run consumer locally (requires infrastructure to be running)
run-consumer:
	cd consumer && go run main.go

# Test with sample file (requires PDF in test_pdfs/)
test-sample:
	@if [ ! -f test_pdfs/sample.pdf ]; then echo "Please create test_pdfs/sample.pdf first"; exit 1; fi
	docker-compose exec producer ./producer /app/pdfs/sample.pdf

# Download dependencies
deps:
	cd producer && go mod tidy
	cd consumer && go mod tidy

# Show logs
logs:
	docker-compose logs -f

# Show logs for specific service
logs-producer:
	docker-compose logs -f producer

logs-consumer:
	docker-compose logs -f consumer

logs-kafka:
	docker-compose logs -f kafka

logs-tika:
	docker-compose logs -f tika

# Help
help:
	@echo "Available commands:"
	@echo "  build          - Build both producer and consumer"
	@echo "  start          - Start all services with Docker Compose"
	@echo "  dev_infra      - Start only infrastructure for local development"
	@echo "  dev_apps       - Start application services"
	@echo "  stop           - Stop all services"
	@echo "  clean          - Clean everything (containers, images, volumes)"
	@echo "  run-producer   - Run producer locally (usage: make run-producer FILE=/path/to/pdf)"
	@echo "  run-consumer   - Run consumer locally"
	@echo "  test-sample    - Test with sample PDF file"
	@echo "  deps           - Download dependencies"
	@echo "  logs           - Show logs for all services"
	@echo "  logs-*         - Show logs for specific service"
	@echo "  help           - Show this help"

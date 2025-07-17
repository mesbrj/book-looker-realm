.PHONY: build start dev_infra consumer producer stop deps help

# Build both producer and consumer
build:
	@echo "Building producer..."
	cd producer && go build -o producer main.go
	@echo "Building consumer..."
	cd consumer && go build -o consumer main.go
	@echo "Build complete!"

# Start all services with Docker Compose (Latest Kafka - takes longer)
start:
	@echo "Starting all services with latest Kafka..."
	docker-compose up -d

# Start only infrastructure for local development (Latest Kafka)
dev_infra:
	@echo "Starting infrastructure services (latest Kafka)..."
	docker-compose up -d kafka tika

consumer:
	@echo "Starting consumer service..."
	docker-compose up -d consumer

producer:
	@echo "Starting producer service..."
	docker-compose run --rm producer ./producer /app/pdfs/osdc_Pragmatic-systemd_2023.03.15.pdf

# Stop all services
stop:
	docker-compose down

# Download dependencies
deps:
	cd producer && go mod tidy
	cd consumer && go mod tidy

# Help
help:
	@echo "Available commands:"
	@echo "  build          - Build both producer and consumer"
	@echo "  start          - Start all services with Docker Compose (Latest Kafka)"
	@echo "  dev_infra      - Start only infrastructure for local development"
	@echo "  consumer       - Start consumer service"
	@echo "  producer       - Start producer service with a sample PDF"	
	@echo "  stop           - Stop all services"
	@echo "  deps           - Download dependencies"
	@echo "  help           - Show this help"

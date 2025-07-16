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

# Download dependencies
deps:
	cd producer && go mod tidy
	cd consumer && go mod tidy

# Help
help:
	@echo "Available commands:"
	@echo "  build          - Build both producer and consumer"
	@echo "  start          - Start all services with Docker Compose"
	@echo "  dev_infra      - Start only infrastructure for local development"
	@echo "  dev_apps       - Start application services"
	@echo "  stop           - Stop all services"
	@echo "  deps           - Download dependencies"
	@echo "  help           - Show this help"

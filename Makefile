.PHONY: build start dev_infra consumer producer stop deps ory-setup ory-start ory-stop ory-status help

# Build both producer and consumer
build:
	@echo "Building producer..."
	cd producers/go_cli && go build -o producer main.go
	@echo "Building consumer..."
	cd consumer && go build -o consumer main.go
	@echo "Build complete!"

# Start all services with Docker Compose (Latest Kafka - takes longer)
start:
	@echo "Starting all services with latest Kafka..."
	cd deploys/cli_producer && docker-compose up -d

# Start only infrastructure for local development (Latest Kafka)
dev_infra:
	@echo "Starting infrastructure services (latest Kafka)..."
	cd deploys/cli_producer && docker-compose up -d kafka tika

consumer:
	@echo "Starting consumer service..."
	cd deploys/cli_producer && docker-compose up -d consumer

producer:
	@echo "Starting producer service..."
	cd deploys/cli_producer && docker-compose run --rm producer ./producer /app/samples/osdc_Pragmatic-systemd_2023.03.15.pdf

# Stop all services
stop:
	cd deploys/cli_producer && docker-compose down

# Download dependencies
deps:
	cd producers/go_cli && go mod tidy
	cd consumer && go mod tidy

# Ory Ecosystem Management
ory-setup:
	@echo "🚀 Setting up Ory ecosystem (Hydra, Kratos, Keto, Oathkeeper)..."
	cd deploys/ory-ecosystem && ./setup.sh

ory-start:
	@echo "🐳 Starting Ory ecosystem services..."
	cd deploys/ory-ecosystem && docker-compose up -d

ory-stop:
	@echo "🛑 Stopping Ory ecosystem services..."
	cd deploys/ory-ecosystem && docker-compose down

ory-status:
	@echo "📊 Checking Ory ecosystem status..."
	@echo "Hydra Public (4444):"
	@curl -s http://localhost:4444/health/ready && echo "✅ Ready" || echo "❌ Not Ready"
	@echo "Hydra Admin (4445):"
	@curl -s http://localhost:4445/health/ready && echo "✅ Ready" || echo "❌ Not Ready"
	@echo "Kratos Public (4433):"
	@curl -s http://localhost:4433/health/ready && echo "✅ Ready" || echo "❌ Not Ready"
	@echo "Kratos Admin (4434):"
	@curl -s http://localhost:4434/health/ready && echo "✅ Ready" || echo "❌ Not Ready"
	@echo "Keto Read (4466):"
	@curl -s http://localhost:4466/health/ready && echo "✅ Ready" || echo "❌ Not Ready"
	@echo "Keto Write (4467):"
	@curl -s http://localhost:4467/health/ready && echo "✅ Ready" || echo "❌ Not Ready"
	@echo "Oathkeeper (4455):"
	@curl -s http://localhost:4455/health/ready && echo "✅ Ready" || echo "❌ Not Ready"


# Help
help:
	@echo "📚 Available commands for book-looker-realm:"
	@echo ""
	@echo "🔧 Core Services:"
	@echo "  build          - Build both producer and consumer"
	@echo "  start          - Start all services with Docker Compose (Latest Kafka)"
	@echo "  dev_infra      - Start only infrastructure for local development"
	@echo "  consumer       - Start consumer service"
	@echo "  producer       - Start producer service with a sample PDF"	
	@echo "  stop           - Stop all services"
	@echo "  deps           - Download dependencies"
	@echo ""
	@echo "🔐 Ory Ecosystem (IAM/CIAM):"
	@echo "  ory-setup      - Setup complete Ory ecosystem with certificates and clients"
	@echo "  ory-start      - Start Ory services (Hydra, Kratos, Keto, Oathkeeper)"
	@echo "  ory-stop       - Stop Ory ecosystem services"
	@echo "  ory-status     - Check health status of all Ory services"
	@echo ""
	@echo "📖 Documentation:"
	@echo "  • Project overview: README.md"
	@echo "  • Ory integration: deploys/ory-ecosystem/INTEGRATION.md"
	@echo "  • Kerberos delegation: docs/alternative-constrained-delegation.png"
	@echo ""
	@echo "🚀 Quick Start:"
	@echo "  1. make dev_infra     # Start Kafka + Tika"
	@echo "  2. make ory-setup     # Setup Ory ecosystem"
	@echo "  3. make build         # Build Go services"
	@echo "  4. make producer      # Test with sample PDF"

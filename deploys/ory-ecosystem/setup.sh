#!/bin/bash

# Streamlined setup script for Ory ecosystem with Kerberos integration
# This script initializes the Ory ecosystem for book-looker-realm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Setting up Ory Ecosystem for book-looker-realm"
echo "🔐 Including kerby-instruments integration setup..."

# Check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is required but not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose is required but not installed"
        exit 1
    fi
    
    echo "✅ Prerequisites check passed"
}

# Main setup function
main() {
    check_prerequisites
    
    # Generate certificates using modular script
    echo "🔐 Generating PKI certificates..."
    "${SCRIPT_DIR}/scripts/generate-certificates.sh"
    
    # Start services
    echo "🐳 Starting Ory ecosystem services..."
    docker-compose up -d
    
    # Wait for services to be ready
    echo "⏳ Waiting for services to start..."
    sleep 10
    
    # Setup Hydra clients using modular script
    echo "🔧 Setting up OAuth2 clients..."
    "${SCRIPT_DIR}/scripts/setup-hydra-clients.sh"
    
    # Setup kerby-instruments integration using modular script
    echo "🔑 Setting up kerby-instruments integration..."
    "${SCRIPT_DIR}/scripts/setup-kerby-instruments.sh"
    
    display_summary
}

# Display setup summary
display_summary() {
    echo ""
    echo "🎉 Ory Ecosystem Setup Complete!"
    echo "================================="
    echo ""
    echo "🌐 Service URLs:"
    echo "  • Hydra Public: http://localhost:4444"
    echo "  • Hydra Admin: http://localhost:4445"
    echo "  • Kratos Public: http://localhost:4433"
    echo "  • Kratos Admin: http://localhost:4434"
    echo "  • Keto Read: http://localhost:4466"
    echo "  • Keto Write: http://localhost:4467"
    echo "  • Oathkeeper: http://localhost:4455"
    echo "  • MailSlurper: http://localhost:4436"
    echo "  • PKI Services: http://localhost:8080"
    echo ""
    echo "🔐 PKI Infrastructure:"
    echo "  • CA Certificate: certs/ca.crt"
    echo "  • Server Certificate: certs/server.crt"
    echo "  • Client Certificate: certs/client.crt"
    echo "  • CRL Endpoint: http://localhost:8080/crl/ca.crl"
    echo "  • OCSP Endpoint: http://localhost:8080/ocsp"
    echo ""
    echo "🔗 kerby-instruments Integration:"
    echo "  • Service token saved in: .kerby-instruments-token"
    echo "  • Configuration saved in: kerby-instruments-config.env"
    echo "  • Certificates ready for PKI operations"
    echo "  • Kratos webhooks configured for principal management"
    echo ""
    echo "📊 Health Check:"
    echo "  Run 'make ory-status' to check service health"
    echo ""
    echo "📚 Next Steps:"
    echo "  1. Deploy kerby-instruments service"
    echo "  2. Configure your Spring Boot application"
    echo "  3. Test OAuth2 flows with your applications"
    echo ""
    echo "✅ Setup completed successfully!"
}

# Make scripts executable
chmod +x "${SCRIPT_DIR}/scripts"/*.sh

# Run main function
main "$@"

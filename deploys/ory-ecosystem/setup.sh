#!/bin/bash

# Setup script for Ory ecosystem with Kerberos integration
# This script initializes the Ory ecosystem for book-looker-realm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"

echo "🚀 Setting up Ory Ecosystem for book-looker-realm..."

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

# Generate self-signed certificates for development
generate_certificates() {
    echo "🔐 Generating self-signed certificates for development..."
    
    mkdir -p "${CERTS_DIR}"
    cd "${CERTS_DIR}"
    
    # Generate CA private key
    if [ ! -f ca.key ]; then
        echo "  📄 Generating CA private key..."
        openssl genrsa -out ca.key 4096
    fi
    
    # Generate CA certificate
    if [ ! -f ca.crt ]; then
        echo "  📄 Generating CA certificate..."
        openssl req -new -x509 -key ca.key -sha256 -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=book-looker-ca" -days 3650 -out ca.crt
    fi
    
    # Generate server private key
    if [ ! -f server.key ]; then
        echo "  📄 Generating server private key..."
        openssl genrsa -out server.key 4096
    fi
    
    # Generate server certificate signing request
    if [ ! -f server.csr ]; then
        echo "  📄 Generating server CSR..."
        openssl req -new -key server.key -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=localhost" -out server.csr
    fi
    
    # Generate server certificate
    if [ ! -f server.crt ]; then
        echo "  📄 Generating server certificate..."
        openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256
    fi
    
    # Generate client private key for testing
    if [ ! -f client.key ]; then
        echo "  📄 Generating client private key..."
        openssl genrsa -out client.key 4096
    fi
    
    # Generate client certificate for testing
    if [ ! -f client.csr ]; then
        echo "  📄 Generating client CSR..."
        openssl req -new -key client.key -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=test-client" -out client.csr
    fi
    
    if [ ! -f client.crt ]; then
        echo "  📄 Generating client certificate with Client Authentication EKU..."
        # Create extension file for client authentication
        cat > client.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = test-client
DNS.2 = localhost
EOF
        openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256 -extensions v3_req -extfile client.ext
        rm client.ext client.csr
    fi
    
    # Set appropriate permissions
    chmod 600 *.key
    chmod 644 *.crt
    
    echo "✅ Certificates generated successfully"
    cd "${SCRIPT_DIR}"
}

# Initialize Hydra clients
setup_hydra_clients() {
    echo "🔧 Setting up Hydra OAuth2 clients..."
    
    # Wait for Hydra to be ready
    echo "  ⏳ Waiting for Hydra to be ready..."
    timeout 60 bash -c 'until curl -s http://localhost:4445/health/ready; do sleep 2; done'
    
    # Create client for kerby-instruments (Client Credentials flow)
    echo "  👤 Creating kerby-instruments client..."
    docker-compose exec -T hydra hydra create client \
        --endpoint http://localhost:4445 \
        --id kerby-instruments \
        --secret kerby-instruments-secret \
        --grant-types client_credentials \
        --response-types token \
        --scope "realm.admin,kerberos.delegation,certificate.issue" \
        --token-endpoint-auth-method client_secret_basic || echo "Client may already exist"
    
    # Create client for Oathkeeper
    echo "  🛡️  Creating Oathkeeper client..."
    docker-compose exec -T hydra hydra create client \
        --endpoint http://localhost:4445 \
        --id oathkeeper \
        --secret oathkeeper-secret \
        --grant-types client_credentials \
        --response-types token \
        --scope introspect \
        --token-endpoint-auth-method client_secret_basic || echo "Client may already exist"
    
    # Create basic client for testing
    echo "  🧪 Creating test client..."
    docker-compose exec -T hydra hydra create client \
        --endpoint http://localhost:4445 \
        --id test-client \
        --secret test-client-secret \
        --grant-types client_credentials \
        --response-types token \
        --scope "test.access" \
        --token-endpoint-auth-method client_secret_basic || echo "Client may already exist"
    
    echo "✅ Hydra clients created successfully"
}

# Setup Keto permissions
setup_keto_permissions() {
    echo "🔒 Setting up Keto permissions..."
    
    # Wait for Keto to be ready
    echo "  ⏳ Waiting for Keto to be ready..."
    timeout 60 bash -c 'until curl -s http://localhost:4467/health/ready; do sleep 2; done'
    
    # Create basic permission relationships for testing
    echo "  📝 Creating basic permission relationships..."
    
    # Create test user with basic permissions
    curl -X PUT http://localhost:4467/admin/relation-tuples \
        -H "Content-Type: application/json" \
        -d '{
            "namespace": "documents",
            "object": "test-document",
            "relation": "viewer",
            "subject_id": "test-user"
        }' || echo "Permission may already exist"
    
    echo "✅ Keto permissions setup completed"
}

# Main setup function
main() {
    check_prerequisites
    generate_certificates
    
    echo "🐳 Starting Ory ecosystem services..."
    docker-compose up -d
    
    # Wait for services to be ready
    echo "⏳ Waiting for services to start..."
    sleep 30
    
    setup_hydra_clients
    setup_keto_permissions
    
    echo ""
    echo "🎉 Ory ecosystem setup completed!"
    echo ""
    echo "📍 Service endpoints:"
    echo "  • Hydra Public:    http://localhost:4444"
    echo "  • Hydra Admin:     http://localhost:4445"
    echo "  • Kratos Public:   http://localhost:4433"
    echo "  • Kratos Admin:    http://localhost:4434"
    echo "  • Keto Read:       http://localhost:4466"
    echo "  • Keto Write:      http://localhost:4467"
    echo "  • Keto OPL:        http://localhost:4468"
    echo "  • Oathkeeper:      http://localhost:4455"
    echo "  • MailSlurper:     http://localhost:4436"
    echo "  • Jaeger:          http://localhost:16686"
    echo ""
    echo "🔧 Next steps:"
    echo "  1. Deploy kerby-instruments service"
    echo "  2. Configure Spring Boot service to use Oathkeeper proxy"
    echo "  3. Set up Kerberos realm integration"
    echo "  4. Configure client applications for OAuth2 flows"
    echo ""
    echo "📚 For integration details, see: README.md"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

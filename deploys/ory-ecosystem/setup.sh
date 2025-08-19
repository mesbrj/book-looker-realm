#!/bin/bash

# Setup script for Ory ecosystem with Kerberos integration
# This script initializes the Ory ecosystem for book-looker-realm including kerby-instruments integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"

echo "🚀 Setting up Ory Ecosystem for book-look# Main setup function
main() {
    check_prerequi    echo "🔗 kerby-instruments Integration:"
    echo "  • Service token saved in: .kerby-instruments-token"
    echo "  • Configuration saved in: kerby-instruments-config.env"
    echo "  • Certificates ready for PKI operations"
    echo "  • Kratos webhooks configured for principal management"
    echo "  • CA trust configured for HTTPS communications"
    generate_certificates
    
    # Check if user wants to build CA-trusted images
    if [ "${BUILD_CA_IMAGES:-false}" == "true" ]; then
        echo "🔧 Building CA-trusted Docker images..."
        build_ca_trusted_images
        echo "🐳 Starting Ory ecosystem services with CA-trusted images..."
        docker-compose -f docker-compose.yml -f docker-compose.ca-trust.yml up -d
    else
        echo "🐳 Starting Ory ecosystem services (using config-based CA trust)..."
        docker-compose up -d
    fi."
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

# Generate self-signed certificates for development and kerby-instruments
generate_certificates() {
    echo "🔐 Generating enhanced PKI with CRL and OCSP support..."
    
    mkdir -p "${CERTS_DIR}"
    cd "${CERTS_DIR}"
    
    # Create PKI directory structure
    mkdir -p {ca,crl,ocsp,issued,private,newcerts}
    chmod 700 private
    
    # Initialize CA database files
    touch ca/index.txt
    echo 1000 > ca/serial
    echo 1000 > ca/crlnumber
    
    # Create OpenSSL CA configuration
    cat > ca.conf << 'EOF'
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = .
certs             = $dir/issued
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/ca/index.txt
serial            = $dir/ca/serial
crlnumber         = $dir/ca/crlnumber

# Root CA certificate and private key
certificate       = $dir/ca.crt
private_key       = $dir/private/ca.key

# CRL settings
crl               = $dir/crl/ca.crl
crl_extensions    = crl_ext
default_crl_days  = 30

# Certificate settings
default_md        = sha256
preserve          = no
policy            = policy_loose

# Certificate extensions
x509_extensions   = usr_cert
copy_extensions   = copy

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
crlDistributionPoints = @crl_info
authorityInfoAccess = @ocsp_info

[ usr_cert ]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
crlDistributionPoints = @crl_info
authorityInfoAccess = @ocsp_info

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
crlDistributionPoints = @crl_info
authorityInfoAccess = @ocsp_info

[ kerby_cert ]
basicConstraints = CA:FALSE
nsComment = "OpenSSL Generated Kerby-Instruments Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth, 1.3.6.1.5.2.3.4, 1.3.6.1.5.2.3.5
crlDistributionPoints = @crl_info
authorityInfoAccess = @ocsp_info

[ kdc_cert ]
basicConstraints = CA:FALSE
nsComment = "OpenSSL Generated KDC Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = 1.3.6.1.5.2.3.5
crlDistributionPoints = @crl_info
authorityInfoAccess = @ocsp_info

[ crl_ext ]
authorityKeyIdentifier=keyid:always

[ ocsp ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning

[ crl_info ]
URI.0 = http://localhost:8080/crl/ca.crl

[ ocsp_info ]
OCSP;URI.0 = http://localhost:8080/ocsp
caIssuers;URI.0 = http://localhost:8080/ca/ca.crt

EOF
    
    # Generate CA private key
    if [ ! -f private/ca.key ]; then
        echo "  📄 Generating CA private key..."
        openssl genrsa -out private/ca.key 4096
        chmod 400 private/ca.key
    fi
    
    # Generate CA certificate
    if [ ! -f ca.crt ]; then
        echo "  📄 Generating CA certificate with CRL and OCSP extensions..."
        openssl req -config ca.conf -key private/ca.key -new -x509 -days 3650 -sha256 -extensions v3_ca \
            -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=book-looker-ca" -out ca.crt
    fi
    
    # Generate initial CRL
    echo "  📄 Generating initial Certificate Revocation List..."
    openssl ca -config ca.conf -gencrl -out crl/ca.crl
    
    # Generate OCSP responder certificate
    if [ ! -f private/ocsp.key ]; then
        echo "  📄 Generating OCSP responder certificate..."
        openssl genrsa -out private/ocsp.key 2048
        chmod 400 private/ocsp.key
        
        openssl req -config ca.conf -new -key private/ocsp.key \
            -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=ocsp.book-looker.realm" -out ocsp.csr
        
        openssl ca -config ca.conf -extensions ocsp -days 365 -notext -md sha256 \
            -in ocsp.csr -out ocsp/ocsp.crt -batch
        
        rm ocsp.csr
    fi
    
    # Generate server private key and certificate
    if [ ! -f private/server.key ]; then
        echo "  📄 Generating server certificate..."
        openssl genrsa -out private/server.key 4096
        chmod 400 private/server.key
        
        openssl req -config ca.conf -new -key private/server.key \
            -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=localhost" -out server.csr
        
        # Add SAN for server certificate
        cat > server.ext << 'EOF'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
crlDistributionPoints = @crl_info
authorityInfoAccess = @ocsp_info

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
DNS.3 = hydra
DNS.4 = kratos  
DNS.5 = keto
DNS.6 = oathkeeper
DNS.7 = kerby-instruments
IP.1 = 127.0.0.1

[crl_info]
URI.0 = http://localhost:8080/crl/ca.crl

[ocsp_info]
OCSP;URI.0 = http://localhost:8080/ocsp
caIssuers;URI.0 = http://localhost:8080/ca/ca.crt
EOF
        
        openssl ca -config ca.conf -extensions server_cert -days 365 -notext -md sha256 \
            -in server.csr -out issued/server.crt -batch -extfile server.ext
        
        # Copy to expected location
        cp issued/server.crt server.crt
        cp private/server.key server.key
        
        rm server.csr server.ext
    fi
    
    # Generate client private key and certificate with proper PKI structure
    if [ ! -f private/client.key ]; then
        echo "  📄 Generating client certificate with proper CA structure..."
        openssl genrsa -out private/client.key 4096
        chmod 400 private/client.key
        
        openssl req -config ca.conf -new -key private/client.key \
            -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=book-looker-client" -out client.csr
        
        openssl ca -config ca.conf -extensions usr_cert -days 365 -notext -md sha256 \
            -in client.csr -out issued/client.crt -batch
        
        # Copy to expected location for backward compatibility
        cp issued/client.crt client.crt
        cp private/client.key client.key
        
        rm client.csr
    fi
    
    # Generate kerby-instruments certificates with specific EKUs for Kerberos and OAuth2
    if [ ! -f kerby-instruments.key ]; then
        echo "  🔐 Generating kerby-instruments private key..."
        openssl genrsa -out kerby-instruments.key 4096
    fi
    
    if [ ! -f kerby-instruments.csr ]; then
        echo "  📄 Generating kerby-instruments CSR..."
        openssl req -new -key kerby-instruments.key -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=kerby-instruments" -out kerby-instruments.csr
    fi
    
    if [ ! -f kerby-instruments.crt ]; then
        echo "  📄 Generating kerby-instruments certificate with Kerberos and OAuth2 EKUs..."
        # Create extension file for kerby-instruments with specific EKUs
        cat > kerby-instruments.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
# Extended Key Usage for Kerberos and OAuth2
extendedKeyUsage = clientAuth, serverAuth, 1.3.6.1.5.2.3.4, 1.3.6.1.5.2.3.5
subjectAltName = @alt_names

[alt_names]
DNS.1 = kerby-instruments
DNS.2 = localhost
DNS.3 = kerby-instruments.book-looker.realm
IP.1 = 127.0.0.1
EOF
        openssl x509 -req -in kerby-instruments.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kerby-instruments.crt -days 365 -sha256 -extensions v3_req -extfile kerby-instruments.ext
        rm kerby-instruments.ext kerby-instruments.csr
    fi
    
    # Generate KDC certificate for Kerberos realm
    if [ ! -f kdc.key ]; then
        echo "  🏛️ Generating KDC private key..."
        openssl genrsa -out kdc.key 4096
    fi
    
    if [ ! -f kdc.csr ]; then
        echo "  📄 Generating KDC CSR..."
        openssl req -new -key kdc.key -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=kdc.book-looker.realm" -out kdc.csr
    fi
    
    if [ ! -f kdc.crt ]; then
        echo "  📄 Generating KDC certificate with Kerberos EKUs..."
        # Create extension file for KDC with Kerberos-specific EKUs
        cat > kdc.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
# Extended Key Usage for Kerberos KDC
extendedKeyUsage = 1.3.6.1.5.2.3.5
subjectAltName = @alt_names

[alt_names]
DNS.1 = kdc.book-looker.realm
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF
        openssl x509 -req -in kdc.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kdc.crt -days 365 -sha256 -extensions v3_req -extfile kdc.ext
        rm kdc.ext kdc.csr
    fi
    
    # Set appropriate permissions
    chmod 600 private/*.key 2>/dev/null || true
    chmod 644 *.crt 2>/dev/null || true
    chmod 644 crl/*.crl 2>/dev/null || true
    chmod 644 ocsp/*.crt 2>/dev/null || true
    
    echo "✅ Enhanced PKI Infrastructure completed!"
    echo "📋 Certificate Authority Details:"
    echo "   - CA Certificate: certs/ca.crt"
    echo "   - Server Certificate: certs/server.crt (with CRL/OCSP extensions)"
    echo "   - Client Certificate: certs/client.crt"
    echo "   - OCSP Responder Certificate: certs/ocsp/ocsp.crt"
    echo "   - CRL File: certs/crl/ca.crl"
    echo "   - kerby-instruments Certificate: certs/kerby-instruments.crt"
    echo "   - KDC Certificate: certs/kdc.crt"
    echo "📋 PKI Endpoints (when services are running):"
    echo "   - CRL Distribution Point: http://localhost:8080/crl/ca.crl"
    echo "   - OCSP Responder: http://localhost:8080/ocsp"
    echo "   - CA Certificate: http://localhost:8080/ca/ca.crt"
    echo "   - PKI Health Check: http://localhost:8080/health"
    
    # Verify CA certificate and extensions
    echo "  🔍 Verifying Enhanced PKI certificates..."
    if openssl x509 -in ca.crt -text -noout | grep -q "book-looker-ca"; then
        echo "    ✅ CA certificate is valid"
    else
        echo "    ⚠️  CA certificate verification failed"
    fi
    
    # Verify server certificate has CRL/OCSP extensions
    if [ -f server.crt ]; then
        if openssl x509 -in server.crt -text -noout | grep -q "CRL Distribution Points"; then
            echo "    ✅ Server certificate includes CRL distribution points"
        else
            echo "    ⚠️  Server certificate missing CRL extensions"
        fi
        
        if openssl x509 -in server.crt -text -noout | grep -q "Authority Information Access"; then
            echo "    ✅ Server certificate includes OCSP endpoints"
        else
            echo "    ⚠️  Server certificate missing OCSP extensions"
        fi
    fi
    
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
    
    # Create kerby-instruments service permissions
    curl -X PUT http://localhost:4467/admin/relation-tuples \
        -H "Content-Type: application/json" \
        -d '{
            "namespace": "realm",
            "object": "BOOK-LOOKER.REALM",
            "relation": "admin",
            "subject_id": "kerby-instruments"
        }' || echo "Permission may already exist"
    
    echo "✅ Keto permissions setup completed"
}

# Setup kerby-instruments integration tokens
setup_kerby_instruments_integration() {
    echo "🔗 Setting up kerby-instruments integration..."
    
    # Generate service token for webhook authentication
    echo "  🔑 Generating service authentication token..."
    SERVICE_TOKEN=$(openssl rand -hex 32)
    
    # Save token to file for kerby-instruments to use
    echo "${SERVICE_TOKEN}" > "${SCRIPT_DIR}/.kerby-instruments-token"
    chmod 600 "${SCRIPT_DIR}/.kerby-instruments-token"
    
    echo "  📄 Service token saved to .kerby-instruments-token"
    echo "  ⚠️  Make sure kerby-instruments uses this token for webhook authentication"
    
    # Create configuration snippet for kerby-instruments
    cat > "${SCRIPT_DIR}/kerby-instruments-config.env" << EOF
# kerby-instruments integration configuration
KRATOS_WEBHOOK_TOKEN=${SERVICE_TOKEN}
HYDRA_CLIENT_ID=kerby-instruments
HYDRA_CLIENT_SECRET=kerby-instruments-secret
HYDRA_TOKEN_URL=http://hydra:4444/oauth2/token
HYDRA_INTROSPECT_URL=http://hydra:4445/admin/oauth2/introspect
KRATOS_PUBLIC_URL=http://kratos:4433
KRATOS_ADMIN_URL=http://kratos:4434
KETO_READ_URL=http://keto:4466
KETO_WRITE_URL=http://keto:4467
REALM_NAME=BOOK-LOOKER.REALM
PKI_CA_CERT=${SCRIPT_DIR}/certs/ca.crt
PKI_CA_KEY=${SCRIPT_DIR}/certs/ca.key
KERBY_INSTRUMENTS_CERT=${SCRIPT_DIR}/certs/kerby-instruments.crt
KERBY_INSTRUMENTS_KEY=${SCRIPT_DIR}/certs/kerby-instruments.key
KDC_CERT=${SCRIPT_DIR}/certs/kdc.crt
KDC_KEY=${SCRIPT_DIR}/certs/kdc.key
EOF
    
    echo "  📄 Configuration saved to kerby-instruments-config.env"
    echo "    echo "✅ kerby-instruments integration setup completed"
}

# Validate CA trust configuration
validate_ca_configuration() {
    echo "🔍 Validating CA trust configuration..."
    
    # Check if CA certificate exists
    if [ ! -f "${CERTS_DIR}/ca.crt" ]; then
        echo "❌ CA certificate not found at ${CERTS_DIR}/ca.crt"
        return 1
    fi
    
    # Check CA certificate validity
    if ! openssl x509 -in "${CERTS_DIR}/ca.crt" -checkend 86400 -noout; then
        echo "⚠️  CA certificate expires within 24 hours"
    else
        echo "✅ CA certificate is valid"
    fi
    
    # Check configuration files for CA references
    local config_files=(
        "config/hydra/hydra.yml"
        "config/kratos/kratos.yml" 
        "config/keto/keto.yml"
        "config/oathkeeper/oathkeeper.yml"
    )
    
    for config_file in "${config_files[@]}"; do
        if grep -q "ca_cert_file.*certs/ca.crt" "${config_file}"; then
            echo "✅ ${config_file} configured for CA trust"
        else
            echo "⚠️  ${config_file} may not have CA trust configured"
        fi
    done
    
    echo "✅ CA trust validation completed"
}

# Main setup function
main() {
    check_prerequisites
    generate_certificates
    validate_ca_configuration
    
    echo "🐳 Starting Ory ecosystem services..."
    docker-compose up -d"
}

# Build custom Ory images with CA trust
build_ca_trusted_images() {
    echo "🐳 Building CA-trusted Ory images..."
    
    # Check if certificates exist
    if [ ! -f "${CERTS_DIR}/ca.crt" ]; then
        echo "❌ CA certificate not found. Run certificate generation first."
        return 1
    fi
    
    # Navigate to script directory for proper build context
    cd "${SCRIPT_DIR}"
    
    # Build Hydra image with CA trust
    echo "  🔨 Building Hydra image with CA trust..."
    docker build -f Dockerfile.ca-trust \
        --build-arg ORY_IMAGE=oryd/hydra:v2.2.0 \
        -t book-looker-realm/hydra:ca-trust \
        --no-cache .
    
    # Build Kratos image with CA trust
    echo "  🔨 Building Kratos image with CA trust..."
    docker build -f Dockerfile.ca-trust \
        --build-arg ORY_IMAGE=oryd/kratos:v1.0.0 \
        -t book-looker-realm/kratos:ca-trust \
        --no-cache .
    
    # Build Keto image with CA trust
    echo "  🔨 Building Keto image with CA trust..."
    docker build -f Dockerfile.ca-trust \
        --build-arg ORY_IMAGE=oryd/keto:v0.11.1 \
        -t book-looker-realm/keto:ca-trust \
        --no-cache .
    
    # Build Oathkeeper image with CA trust
    echo "  🔨 Building Oathkeeper image with CA trust..."
    docker build -f Dockerfile.ca-trust \
        --build-arg ORY_IMAGE=oryd/oathkeeper:v0.40.6 \
        -t book-looker-realm/oathkeeper:ca-trust \
        --no-cache .
    
    echo "✅ CA-trusted images built successfully"
    echo "  ℹ️  Use 'docker-compose -f docker-compose.yml -f docker-compose.ca-trust.yml up -d' to run with CA trust"
}

# Main setup function
main() {
    check_prerequisites
    generate_certificates
    
    echo "� Building CA-trusted Docker images..."
    build_ca_trusted_images
    
    echo "�🐳 Starting Ory ecosystem services..."
    docker-compose up -d
    
    # Wait for services to be ready
    echo "⏳ Waiting for services to start..."
    sleep 30
    
    setup_hydra_clients
    setup_keto_permissions
    setup_kerby_instruments_integration
    
    echo ""
    echo "🎉 Ory ecosystem setup completed!"
    echo ""
    echo "📍 Service endpoints:"
    echo "  • Hydra Public:       http://localhost:4444"
    echo "  • Hydra Admin:        http://localhost:4445"
    echo "  • Kratos Public:      http://localhost:4433"
    echo "  • Kratos Admin:       http://localhost:4434"
    echo "  • Keto Read:          http://localhost:4466"
    echo "  • Keto Write:         http://localhost:4467"
    echo "  • Keto OPL:           http://localhost:4468"
    echo "  • Oathkeeper:         http://localhost:4455"
    echo "  • kerby-instruments:  https://localhost:8443 (placeholder)"
    echo "  • MailSlurper:        http://localhost:4436"
    echo "  • Jaeger:             http://localhost:16686"
    echo ""
    echo "� kerby-instruments Integration:"
    echo "  • Service token saved in: .kerby-instruments-token"
    echo "  • Configuration saved in: kerby-instruments-config.env"
    echo "  • Certificates ready for PKI operations"
    echo "  • Kratos webhooks configured for principal management"
    echo ""
    echo "🔧 Next steps:"
    echo "  1. Implement kerby-instruments API endpoints (see KERBY-INSTRUMENTS-INTEGRATION.md)"
    echo "  2. Replace nginx placeholder with real kerby-instruments service"
    echo "  3. Deploy Spring Boot Resource Server"
    echo "  4. Configure Kerberos KDC integration"
    echo "  5. Test end-to-end user registration → principal creation → certificate issuance"
    echo ""
    echo "📚 For integration details, see:"
    echo "  • README.md"
    echo "  • KERBY-INSTRUMENTS-INTEGRATION.md"
    echo "  • INTEGRATION.md"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

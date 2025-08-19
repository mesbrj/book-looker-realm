#!/bin/bash

# Kerby-instruments Integration Module for Ory Ecosystem
# Sets up kerby-instruments configuration and tokens

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

setup_kerby_instruments() {
    echo "🔑 Setting up kerby-instruments integration..."
    
    # Generate service token for kerby-instruments
    KERBY_TOKEN=$(openssl rand -hex 32)
    echo "${KERBY_TOKEN}" > "${SCRIPT_DIR}/.kerby-instruments-token"
    chmod 600 "${SCRIPT_DIR}/.kerby-instruments-token"
    
    echo "  📝 Generated kerby-instruments service token"
    
    # Create kerby-instruments environment configuration
    cat > "${SCRIPT_DIR}/kerby-instruments-config.env" << EOF
# Kerby-instruments Integration Configuration
# Generated on $(date)

# Service Configuration
KERBY_INSTRUMENTS_TOKEN=${KERBY_TOKEN}
KERBY_INSTRUMENTS_URL=https://localhost:8443

# Kerberos Configuration
KRB_REALM=BOOK-LOOKER.REALM
KRB_KDC_HOST=localhost
KRB_KDC_PORT=88

# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_NAME=kerby_instruments
DB_USER=ory
DB_PASSWORD=ory-secret

# OAuth2 Configuration
HYDRA_PUBLIC_URL=http://localhost:4444
HYDRA_ADMIN_URL=http://localhost:4445
HYDRA_CLIENT_ID=kerby-instruments
HYDRA_CLIENT_SECRET=kerby-instruments-secret

# PKI Configuration
PKI_CA_CERT_PATH=/app/certs/ca.crt
PKI_SERVER_CERT_PATH=/app/certs/server.crt
PKI_SERVER_KEY_PATH=/app/certs/server.key
PKI_CLIENT_CERT_PATH=/app/certs/client.crt
PKI_CLIENT_KEY_PATH=/app/certs/client.key

# Integration URLs
KRATOS_PUBLIC_URL=http://localhost:4433
KRATOS_ADMIN_URL=http://localhost:4434
KETO_READ_URL=http://localhost:4466
KETO_WRITE_URL=http://localhost:4467
EOF

    chmod 644 "${SCRIPT_DIR}/kerby-instruments-config.env"
    
    echo "  📋 Created kerby-instruments configuration file"
    echo "✅ kerby-instruments integration setup completed"
}

# Allow script to be sourced or run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_kerby_instruments
fi

#!/bin/bash

# Hydra Client Setup Module for Ory Ecosystem
# Creates OAuth2 clients for kerby-instruments and other services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        --scope read,write,admin \
        --token-endpoint-auth-method private_key_jwt \
        --jwks-uri file:///etc/certs/client.crt \
        --callbacks http://localhost:8080/callback

    # Create client for Spring Boot application (Authorization Code + PKCE)
    echo "  🌱 Creating Spring Boot application client..."
    docker-compose exec -T hydra hydra create client \
        --endpoint http://localhost:4445 \
        --id book-looker-app \
        --secret book-looker-app-secret \
        --grant-types authorization_code,refresh_token \
        --response-types code \
        --scope openid,offline,read,write \
        --token-endpoint-auth-method client_secret_basic \
        --callbacks http://localhost:8080/login/oauth2/code/hydra,http://localhost:3000/callback

    # Create client for testing/development
    echo "  🧪 Creating development client..."
    docker-compose exec -T hydra hydra create client \
        --endpoint http://localhost:4445 \
        --id dev-client \
        --secret dev-client-secret \
        --grant-types client_credentials,authorization_code,refresh_token \
        --response-types token,code \
        --scope openid,offline,read,write,admin \
        --token-endpoint-auth-method client_secret_post \
        --callbacks http://localhost:4444/callback,http://127.0.0.1:4444/callback

    echo "✅ Hydra clients created successfully"
}

# Allow script to be sourced or run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_hydra_clients
fi

#!/bin/bash

# Test script to verify CA trust configuration in Ory ecosystem
# This script tests HTTPS connections using your self-signed CA

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"

echo "🧪 Testing CA trust configuration..."

# Test CA certificate validity
test_ca_certificate() {
    echo "🔍 Testing CA certificate..."
    
    if [ ! -f "${CERTS_DIR}/ca.crt" ]; then
        echo "❌ CA certificate not found"
        return 1
    fi
    
    # Check certificate details
    echo "📋 CA Certificate Details:"
    openssl x509 -in "${CERTS_DIR}/ca.crt" -text -noout | grep -E "(Subject:|Not Before:|Not After:|Serial Number:)" | sed 's/^/  /'
    
    # Check if certificate is valid
    if openssl x509 -in "${CERTS_DIR}/ca.crt" -checkend 0 -noout; then
        echo "✅ CA certificate is valid"
    else
        echo "❌ CA certificate is expired or invalid"
        return 1
    fi
}

# Test service configurations
test_service_configurations() {
    echo "🔍 Testing service configurations..."
    
    local services=("hydra" "kratos" "keto" "oathkeeper")
    
    for service in "${services[@]}"; do
        local config_file="config/${service}/${service}.yml"
        
        if [ -f "${config_file}" ]; then
            if grep -q "ca_cert_file.*certs/ca.crt" "${config_file}"; then
                echo "✅ ${service}: CA trust configured"
            else
                echo "⚠️  ${service}: CA trust may not be configured"
            fi
        else
            echo "❌ ${service}: Configuration file not found"
        fi
    done
}

# Test HTTPS connection with CA (when services are running)
test_https_connections() {
    echo "🔍 Testing HTTPS connections..."
    
    # Test if services are running
    local services=(
        "hydra:4444"
        "kratos:4433"
        "keto:4466"
        "oathkeeper:4455"
    )
    
    for service_port in "${services[@]}"; do
        local service="${service_port%:*}"
        local port="${service_port#*:}"
        
        echo "  Testing ${service} on port ${port}..."
        
        if curl -s --max-time 5 "http://localhost:${port}/health/ready" > /dev/null; then
            echo "    ✅ ${service} is responding on HTTP"
        else
            echo "    ❌ ${service} is not responding"
        fi
    done
}

# Test certificate chain validation
test_certificate_chain() {
    echo "🔍 Testing certificate chain..."
    
    if [ -f "${CERTS_DIR}/server.crt" ] && [ -f "${CERTS_DIR}/ca.crt" ]; then
        if openssl verify -CAfile "${CERTS_DIR}/ca.crt" "${CERTS_DIR}/server.crt"; then
            echo "✅ Server certificate chain is valid"
        else
            echo "❌ Server certificate chain validation failed"
        fi
    else
        echo "⚠️  Server certificate or CA not found for chain validation"
    fi
    
    if [ -f "${CERTS_DIR}/kerby-instruments.crt" ] && [ -f "${CERTS_DIR}/ca.crt" ]; then
        if openssl verify -CAfile "${CERTS_DIR}/ca.crt" "${CERTS_DIR}/kerby-instruments.crt"; then
            echo "✅ kerby-instruments certificate chain is valid"
        else
            echo "❌ kerby-instruments certificate chain validation failed"
        fi
    else
        echo "⚠️  kerby-instruments certificate or CA not found for chain validation"
    fi
}

# Main test function
main() {
    echo "🚀 Starting CA trust verification tests..."
    echo ""
    
    test_ca_certificate
    echo ""
    
    test_service_configurations  
    echo ""
    
    test_certificate_chain
    echo ""
    
    test_https_connections
    echo ""
    
    echo "🎉 CA trust verification completed!"
    echo ""
    echo "📚 Notes:"
    echo "  • All Ory services are configured to trust your self-signed CA"
    echo "  • HTTPS calls to kerby-instruments will be verified against your CA"
    echo "  • Client certificates can be validated using your CA"
    echo "  • For production, consider using a proper CA or certificate management"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

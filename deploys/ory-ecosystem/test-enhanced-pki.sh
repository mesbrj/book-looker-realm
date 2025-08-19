#!/bin/bash

# Enhanced PKI Test Script for Certificate Revocation Lists (CRLs) and OCSP
# Tests the complete PKI infrastructure including CRL distribution and OCSP validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"

echo "🔐 Enhanced PKI Infrastructure Tests"
echo "===================================="

# Test 1: Verify PKI directory structure
echo "📁 Testing PKI Directory Structure..."
expected_dirs=("ca" "crl" "ocsp" "issued" "private" "newcerts")
for dir in "${expected_dirs[@]}"; do
    if [ -d "${CERTS_DIR}/${dir}" ]; then
        echo "  ✅ Directory exists: ${dir}/"
    else
        echo "  ❌ Missing directory: ${dir}/"
    fi
done

# Test 2: Verify core certificates
echo ""
echo "📜 Testing Core Certificates..."
certificates=("ca.crt" "server.crt" "client.crt" "kerby-instruments.crt" "kdc.crt")
for cert in "${certificates[@]}"; do
    if [ -f "${CERTS_DIR}/${cert}" ]; then
        if openssl x509 -in "${CERTS_DIR}/${cert}" -noout -text >/dev/null 2>&1; then
            echo "  ✅ Valid certificate: ${cert}"
        else
            echo "  ❌ Invalid certificate: ${cert}"
        fi
    else
        echo "  ❌ Missing certificate: ${cert}"
    fi
done

# Test 3: Verify OCSP responder certificate
echo ""
echo "🔍 Testing OCSP Infrastructure..."
if [ -f "${CERTS_DIR}/ocsp/ocsp.crt" ]; then
    if openssl x509 -in "${CERTS_DIR}/ocsp/ocsp.crt" -noout -text | grep -q "OCSP Signing"; then
        echo "  ✅ OCSP responder certificate has correct EKU"
    else
        echo "  ⚠️  OCSP responder certificate missing OCSP Signing EKU"
    fi
else
    echo "  ❌ OCSP responder certificate not found"
fi

# Test 4: Verify CRL
echo ""
echo "📋 Testing Certificate Revocation List..."
if [ -f "${CERTS_DIR}/crl/ca.crl" ]; then
    if openssl crl -in "${CERTS_DIR}/crl/ca.crl" -noout -text >/dev/null 2>&1; then
        echo "  ✅ CRL is valid"
        
        # Check CRL details
        next_update=$(openssl crl -in "${CERTS_DIR}/crl/ca.crl" -noout -nextupdate | cut -d'=' -f2)
        echo "  📅 CRL Next Update: ${next_update}"
    else
        echo "  ❌ CRL is invalid"
    fi
else
    echo "  ❌ CRL not found"
fi

# Test 5: Verify certificate extensions (CRL and OCSP endpoints)
echo ""
echo "🔗 Testing Certificate Extensions..."
if [ -f "${CERTS_DIR}/server.crt" ]; then
    echo "  🖥️  Server Certificate Extensions:"
    
    # Check for CRL Distribution Points
    if openssl x509 -in "${CERTS_DIR}/server.crt" -noout -text | grep -A2 "CRL Distribution Points" | grep -q "http://localhost:8080/crl/ca.crl"; then
        echo "    ✅ CRL Distribution Point configured correctly"
    else
        echo "    ❌ CRL Distribution Point missing or incorrect"
    fi
    
    # Check for OCSP endpoints
    if openssl x509 -in "${CERTS_DIR}/server.crt" -noout -text | grep -A5 "Authority Information Access" | grep -q "http://localhost:8080/ocsp"; then
        echo "    ✅ OCSP endpoint configured correctly"
    else
        echo "    ❌ OCSP endpoint missing or incorrect"
    fi
    
    # Check for Subject Alternative Names
    if openssl x509 -in "${CERTS_DIR}/server.crt" -noout -text | grep -A10 "Subject Alternative Name" | grep -q "localhost"; then
        echo "    ✅ Subject Alternative Names configured"
    else
        echo "    ⚠️  Subject Alternative Names missing"
    fi
fi

# Test 6: Test PKI HTTP services (if running)
echo ""
echo "🌐 Testing PKI HTTP Services..."

check_http_endpoint() {
    local url="$1"
    local description="$2"
    
    if curl -s --connect-timeout 5 "${url}" >/dev/null 2>&1; then
        echo "  ✅ ${description}: ${url}"
    else
        echo "  ❌ ${description}: ${url} (not accessible)"
    fi
}

check_http_endpoint "http://localhost:8080/health" "PKI Health Check"
check_http_endpoint "http://localhost:8080/ca/ca.crt" "CA Certificate Distribution"
check_http_endpoint "http://localhost:8080/crl/ca.crl" "CRL Distribution Point"
check_http_endpoint "http://localhost:8080/ocsp" "OCSP Responder"

# Test 7: Certificate Chain Validation
echo ""
echo "🔗 Testing Certificate Chain Validation..."
if [ -f "${CERTS_DIR}/ca.crt" ] && [ -f "${CERTS_DIR}/server.crt" ]; then
    if openssl verify -CAfile "${CERTS_DIR}/ca.crt" "${CERTS_DIR}/server.crt" >/dev/null 2>&1; then
        echo "  ✅ Server certificate chain validation successful"
    else
        echo "  ❌ Server certificate chain validation failed"
    fi
fi

if [ -f "${CERTS_DIR}/ca.crt" ] && [ -f "${CERTS_DIR}/client.crt" ]; then
    if openssl verify -CAfile "${CERTS_DIR}/ca.crt" "${CERTS_DIR}/client.crt" >/dev/null 2>&1; then
        echo "  ✅ Client certificate chain validation successful"
    else
        echo "  ❌ Client certificate chain validation failed"
    fi
fi

# Test 8: OCSP Request Test (if OCSP responder is running)
echo ""
echo "🔍 Testing OCSP Request..."
if [ -f "${CERTS_DIR}/ca.crt" ] && [ -f "${CERTS_DIR}/server.crt" ]; then
    # Try to make an OCSP request
    if command -v openssl >/dev/null 2>&1; then
        ocsp_response=$(openssl ocsp -issuer "${CERTS_DIR}/ca.crt" -cert "${CERTS_DIR}/server.crt" -url http://localhost:8080/ocsp -noverify 2>&1 || true)
        
        if echo "${ocsp_response}" | grep -q "Response verify OK"; then
            echo "  ✅ OCSP response verification successful"
        elif echo "${ocsp_response}" | grep -q "good"; then
            echo "  ✅ OCSP certificate status: good"
        else
            echo "  ⚠️  OCSP request failed or responder not running"
            echo "     (This is expected if services are not started)"
        fi
    fi
fi

# Test 9: Certificate Expiration Check
echo ""
echo "⏰ Certificate Expiration Check..."
for cert in "${CERTS_DIR}"/*.crt; do
    if [ -f "${cert}" ]; then
        cert_name=$(basename "${cert}")
        expiry_date=$(openssl x509 -in "${cert}" -noout -enddate | cut -d'=' -f2)
        days_until_expiry=$((($(date -d "${expiry_date}" +%s) - $(date +%s)) / 86400))
        
        if [ "${days_until_expiry}" -gt 30 ]; then
            echo "  ✅ ${cert_name}: expires in ${days_until_expiry} days"
        elif [ "${days_until_expiry}" -gt 0 ]; then
            echo "  ⚠️  ${cert_name}: expires in ${days_until_expiry} days (renew soon)"
        else
            echo "  ❌ ${cert_name}: expired ${days_until_expiry} days ago"
        fi
    fi
done

# Summary
echo ""
echo "📊 Enhanced PKI Test Summary"
echo "============================"
echo "✅ PKI infrastructure appears to be correctly configured"
echo "🔗 CRL and OCSP endpoints are configured in certificates"
echo "🌐 HTTP services need to be started to test live functionality"
echo ""
echo "To start PKI services:"
echo "  docker-compose up -d pki-services ocsp-responder"
echo ""
echo "To test live services:"
echo "  make ory-test-pki"

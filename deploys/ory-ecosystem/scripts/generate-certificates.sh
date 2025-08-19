#!/bin/bash

# PKI Certificate Generation Module for Ory Ecosystem
# Generates CA, server, client, and OCSP certificates with CRL/OCSP support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"

generate_certificates() {
    echo "🔐 Setting up Enhanced PKI Infrastructure..."
    
    # Create directory structure
    mkdir -p "${CERTS_DIR}"/{ca,crl,ocsp,issued,private,newcerts}
    cd "${CERTS_DIR}"
    
    # Initialize CA database files
    [ ! -f ca/index.txt ] && touch ca/index.txt
    [ ! -f ca/serial ] && echo 1000 > ca/serial
    [ ! -f ca/crlnumber ] && echo 1000 > ca/crlnumber
    
    # Create comprehensive OpenSSL CA configuration
    create_ca_config
    
    # Generate CA infrastructure
    generate_ca_certificates
    
    # Generate service certificates
    generate_service_certificates
    
    # Set permissions and verify
    set_permissions_and_verify
    
    cd "${SCRIPT_DIR}"
}

create_ca_config() {
    cat > ca.conf << 'EOF'
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = .
certs             = $dir
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/ca/index.txt
serial            = $dir/ca/serial
RANDFILE          = $dir/private/.rand
private_key       = $dir/private/ca.key
certificate       = $dir/ca.crt
crlnumber         = $dir/ca/crlnumber
crl               = $dir/crl/ca.crl
crl_extensions    = crl_ext
default_crl_days  = 30
default_md        = sha256
name_opt          = ca_default
cert_opt          = ca_default
default_days      = 365
preserve          = no
policy            = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
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
}

generate_ca_certificates() {
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
}

generate_service_certificates() {
    # Generate server certificate
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
    
    # Generate client certificate
    if [ ! -f private/client.key ]; then
        echo "  📄 Generating client certificate..."
        openssl genrsa -out private/client.key 4096
        chmod 400 private/client.key
        
        openssl req -config ca.conf -new -key private/client.key \
            -subj "/C=US/ST=Dev/L=Local/O=BookLookerRealm/CN=book-looker-client" -out client.csr
        
        openssl ca -config ca.conf -extensions usr_cert -days 365 -notext -md sha256 \
            -in client.csr -out issued/client.crt -batch
        
        # Copy to expected location
        cp issued/client.crt client.crt
        cp private/client.key client.key
        
        rm client.csr
    fi
}

set_permissions_and_verify() {
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
}

# Allow script to be sourced or run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_certificates
fi

# Kerby-instruments Integration with Ory Kratos

This document explains how Ory Kratos integrates with the `kerby-instruments` service for Kerberos principal management in the book-looker-realm project.

## 🎯 Integration Overview

The integration allows Kratos to:
- **Delegate principal management** to kerby-instruments
- **Trigger certificate generation** when users register/verify
- **Validate Kerberos principals** during identity operations
- **Sync user lifecycle events** with the Kerberos realm

## 🔗 API Endpoints

### kerby-instruments Expected Endpoints

When you implement kerby-instruments, it should provide these HTTPS endpoints:

#### 1. Principal Management
```
POST https://kerby-instruments:8443/api/v1/principals/register
POST https://kerby-instruments:8443/api/v1/principals/validate
POST https://kerby-instruments:8443/api/v1/principals/kratos-registration
POST https://kerby-instruments:8443/api/v1/principals/kratos-settings-update
```

#### 2. Authentication Events
```
POST https://kerby-instruments:8443/api/v1/principals/login-event
POST https://kerby-instruments:8443/api/v1/principals/verification-completed
POST https://kerby-instruments:8443/api/v1/principals/recovery-notification
```

#### 3. Certificate Management
```
GET  https://kerby-instruments:8443/api/v1/certificates/user/{principal}
POST https://kerby-instruments:8443/api/v1/certificates/generate
POST https://kerby-instruments:8443/api/v1/certificates/revoke
GET  https://kerby-instruments:8443/api/v1/certificates/ca/public-key
```

#### 4. OAuth2/Auth Callbacks
```
POST https://kerby-instruments:8443/auth/callback
GET  https://kerby-instruments:8443/health
```

## 📝 Webhook Payloads

### Registration Hook (`registration.jsonnet`)
Sent when a new user registers in Kratos:
```json
{
  "identity_id": "uuid",
  "traits": {
    "email": "user@example.com",
    "kerberos_principal": "user@BOOK-LOOKER.REALM",
    "realm": "BOOK-LOOKER.REALM",
    "roles": ["user"]
  },
  "action": "create_principal",
  "realm_context": {
    "realm_name": "BOOK-LOOKER.REALM",
    "require_cert_generation": true,
    "default_roles": ["user"],
    "enable_delegation": false
  }
}
```

### Login Event Hook (`login.jsonnet`)
Sent on every user login:
```json
{
  "identity_id": "uuid",
  "traits": {
    "email": "user@example.com",
    "kerberos_principal": "user@BOOK-LOOKER.REALM",
    "x509_cert_serial": "ABC123"
  },
  "action": "login_event",
  "security_checks": {
    "validate_certificate": true,
    "check_principal_status": true,
    "update_last_login": true,
    "audit_login": true
  }
}
```

### Verification Completed Hook (`verification.jsonnet`)
Sent when email verification is completed:
```json
{
  "identity_id": "uuid",
  "action": "verification_completed",
  "post_verification_actions": {
    "activate_principal": true,
    "generate_certificates": true,
    "enable_kerberos_auth": true,
    "send_welcome_notification": true
  }
}
```

## 🔐 SSL/TLS Configuration

The Ory ecosystem is configured to trust your self-signed CA for HTTPS communications with kerby-instruments:

- **Certificate mounting**: All Ory services have `/etc/certs/ca.crt` mounted
- **Environment variables**: `SSL_CERT_FILE`, `SSL_CERT_DIR`, and `CURL_CA_BUNDLE` set for Go HTTP clients
- **Automatic trust**: No additional configuration needed - just implement HTTPS endpoints in kerby-instruments

## 🔑 Authentication

All webhook requests from Kratos to kerby-instruments use:
```
Authorization: Bearer kerby-instruments-service-token
```

## 🏗️ Implementation Guidelines

### 1. kerby-instruments Response Format
All endpoints should respond with:
```json
{
  "success": true,
  "message": "Operation completed",
  "data": {
    "principal_created": true,
    "certificate_serial": "XYZ789",
    "kerberos_principal": "user@BOOK-LOOKER.REALM"
  },
  "timestamp": "2025-08-19T10:30:00Z"
}
```

### 2. Error Handling
For errors, respond with HTTP 4xx/5xx and:
```json
{
  "success": false,
  "error": "Principal already exists",
  "error_code": "PRINCIPAL_EXISTS",
  "timestamp": "2025-08-19T10:30:00Z"
}
```

### 3. Certificate Generation
When kerby-instruments receives a registration webhook:
1. **Create Kerberos principal** in the realm
2. **Generate X.509 certificate** with Client Authentication EKU
3. **Store certificate serial** in response
4. **Enable principal** for authentication

## 🧪 Testing Integration

### 1. Mock kerby-instruments
For development, you can mock the endpoints:
```bash
# Start mock server
docker run -p 8443:8443 -d mockserver/mockserver

# Configure expectations
curl -X PUT http://localhost:8443/mockserver/expectation \
  -H "Content-Type: application/json" \
  -d '{
    "httpRequest": {
      "path": "/api/v1/principals/register",
      "method": "POST"
    },
    "httpResponse": {
      "statusCode": 200,
      "body": {
        "success": true,
        "data": {
          "principal_created": true,
          "certificate_serial": "MOCK123"
        }
      }
    }
  }'
```

### 2. Test User Registration Flow
```bash
# 1. Start Ory ecosystem
make ory-setup
make ory-start

# 2. Register user via Kratos
curl -X POST http://localhost:4433/self-service/registration/api \
  -H "Content-Type: application/json" \
  -d '{
    "traits": {
      "email": "test@book-looker.realm",
      "kerberos_principal": "test@BOOK-LOOKER.REALM",
      "realm": "BOOK-LOOKER.REALM"
    }
  }'

# 3. Check kerby-instruments logs for webhook calls
docker logs kerby-instruments
```

## 🔄 Current Status

- ✅ **Kratos configuration**: Updated with kerby-instruments integration
- ✅ **Webhook templates**: Created for all lifecycle events
- ✅ **Docker compose**: Placeholder service added
- 🚧 **kerby-instruments**: Work in progress (implement the API endpoints)
- 🚧 **Certificate management**: Pending kerby-instruments implementation
- 🚧 **Kerberos realm**: Pending KDC setup

## 🚀 Next Steps

1. **Implement kerby-instruments service** with the API endpoints listed above
2. **Configure Kerberos KDC** integration
3. **Set up certificate generation** pipeline
4. **Test end-to-end** user registration → principal creation → certificate issuance
5. **Add monitoring** and logging for the integration

## 📚 References

- [Ory Kratos Webhooks Documentation](https://www.ory.sh/docs/kratos/hooks/configure)
- [Apache Kerby Documentation](https://directory.apache.org/kerby/)
- [X.509 Certificate Extensions for Kerberos](https://web.mit.edu/Kerberos/krb5-1.12/doc/admin/pkinit.html)

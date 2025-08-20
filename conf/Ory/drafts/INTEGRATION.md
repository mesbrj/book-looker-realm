# Ory Ecosystem Integration Guide for book-looker-realm

This guide explains how to integrate the Ory ecosystem (Hydra, Kratos, Keto, Oathkeeper) with your Kerberos-enabled document processing system.

## Architecture Overview

The integration provides:

1. **Identity Management** (Kratos) - User registration, login, and Kerberos principal mapping
2. **OAuth2/OIDC Provider** (Hydra) - Token-based authentication with client certificate support
3. **Authorization Engine** (Keto) - Fine-grained permissions for documents, catalogs, and S3 buckets
4. **API Gateway** (Oathkeeper) - Identity proxy with JWT validation and mutation

## Authentication Flow

### 1. Client Certificate + JWT Flow (Recommended)

```
Client App → kerby-instruments → Hydra → Oathkeeper → Your Services
     ↑              ↓              ↓         ↓
  x.509 cert    Signed JWT    OAuth2 Token  Mutated Headers
```

**Steps:**
1. Client uses x.509 certificate from kerby-instruments to create signed JWT
2. JWT is exchanged for OAuth2 token at Hydra (Client Credentials flow)
3. Oathkeeper validates token and adds identity headers
4. Your services receive authenticated requests with user context

### 2. Authorization Code Flow (JavaFX/Web clients)

```
User → Login UI → Kratos → Hydra → Client App → Oathkeeper → Your Services
```

## Quick Start

### 1. Deploy Ory Ecosystem

```bash
cd deploys/ory-ecosystem
./setup.sh
```

This will:
- Start all Ory services with PostgreSQL
- Generate development certificates
- Create OAuth2 clients for your services
- Setup basic permissions in Keto

### 2. Integration Points

#### A. kerby-instruments Integration

**JWT Creation in kerby-instruments:**
```java
// In kerby-instruments, create signed JWT with user's client certificate
JWTCreator.Builder jwt = JWT.create()
    .withIssuer("kerby-instruments")
    .withSubject(kerberosUserPrincipal)
    .withAudience("hydra")
    .withClaim("kerberos_principal", userPrincipal)
    .withClaim("realm", "BOOK-LOOKER.REALM")
    .withClaim("x509_cert_serial", clientCertSerial)
    .withClaim("scope", Arrays.asList("api.access", "document.process"));

String signedJWT = jwt.sign(Algorithm.RSA256(privateKey, certificate));
```

**Hydra Token Exchange:**
```bash
curl -X POST http://localhost:4444/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  -d "client_assertion=${SIGNED_JWT}" \
  -d "scope=api.access document.process"
```

#### B. Spring Boot Service Integration

**Application Properties:**
```yaml
# Configure to use Oathkeeper proxy
server:
  port: 8080

# OAuth2 Resource Server configuration
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://localhost:4444
          jwk-set-uri: http://localhost:4444/.well-known/jwks.json

# Access Oathkeeper headers for user context
security:
  user-header: X-User-ID
  kerberos-header: X-Kerberos-Principal
  roles-header: X-User-Roles
```

**Security Configuration:**
```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            )
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/health").permitAll()
                .requestMatchers("/api/**").authenticated()
                .anyRequest().authenticated()
            )
            .build();
    }
    
    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            // Extract authorities from Oathkeeper headers
            String roles = extractHeaderFromJWT(jwt, "X-User-Roles");
            return parseRoles(roles);
        });
        return converter;
    }
}
```

#### C. JavaFX Client Integration

**OAuth2 Configuration:**
```java
// Authorization Code Flow with PKCE
public class OAuth2Client {
    private static final String CLIENT_ID = "javafx-desktop";
    private static final String AUTHORIZATION_ENDPOINT = "http://localhost:4444/oauth2/auth";
    private static final String TOKEN_ENDPOINT = "http://localhost:4444/oauth2/token";
    private static final String REDIRECT_URI = "http://localhost:8081/oauth/callback";
    
    public void startAuthFlow() {
        String codeVerifier = generateCodeVerifier();
        String codeChallenge = generateCodeChallenge(codeVerifier);
        
        String authUrl = AUTHORIZATION_ENDPOINT + 
            "?response_type=code" +
            "&client_id=" + CLIENT_ID +
            "&redirect_uri=" + REDIRECT_URI +
            "&scope=api.access document.process" +
            "&code_challenge=" + codeChallenge +
            "&code_challenge_method=S256";
            
        // Open browser or embedded webview
        openBrowser(authUrl);
    }
}
```

#### D. Go TUI Integration

**Client Credentials Flow:**
```go
// OAuth2 client configuration
config := clientcredentials.Config{
    ClientID:     "go-tui",
    ClientSecret: "go-tui-secret",
    TokenURL:     "http://localhost:4444/oauth2/token",
    Scopes:       []string{"api.access", "document.process", "batch.process"},
}

// Get token and make authenticated requests
token, err := config.Token(context.Background())
if err != nil {
    log.Fatal(err)
}

client := config.Client(context.Background())
resp, err := client.Get("http://localhost:4455/api/documents")
```

### 3. Permission Management

#### Setup User Permissions in Keto

```bash
# Grant user document read permission
curl -X PUT http://localhost:4467/admin/relation-tuples \
  -H "Content-Type: application/json" \
  -d '{
    "namespace": "documents",
    "object": "sample.pdf",
    "relation": "viewer",
    "subject_id": "user@BOOK-LOOKER.REALM"
  }'

# Grant S3 bucket access
curl -X PUT http://localhost:4467/admin/relation-tuples \
  -H "Content-Type: application/json" \
  -d '{
    "namespace": "s3_buckets",
    "object": "documents",
    "relation": "uploader",
    "subject_id": "user@BOOK-LOOKER.REALM"
  }'
```

#### Check Permissions

```bash
# Check if user can read document
curl "http://localhost:4466/relation-tuples/check" \
  -G \
  -d "namespace=documents" \
  -d "object=sample.pdf" \
  -d "relation=viewer" \
  -d "subject_id=user@BOOK-LOOKER.REALM"
```

### 4. Service Integration Workflow

#### Complete Request Flow:

1. **Client Authentication:**
   ```
   Client → kerby-instruments (get x.509 cert) → Create signed JWT → Exchange for OAuth2 token
   ```

2. **API Request:**
   ```
   Client (with Bearer token) → Oathkeeper → Token validation → Keto permission check → Spring service
   ```

3. **Service-to-Service:**
   ```
   Spring service → kerby-instruments (delegation JWT) → Kafka/MinIO (with delegated credentials)
   ```

## Monitoring and Debugging

### Service Health Checks

```bash
# Check all services
curl http://localhost:4444/health/ready  # Hydra
curl http://localhost:4433/health/ready  # Kratos
curl http://localhost:4466/health/ready  # Keto
curl http://localhost:4455/health/ready  # Oathkeeper
```

### Debugging Tools

1. **Jaeger Tracing:** http://localhost:16686
2. **MailSlurper:** http://localhost:4436 (for email flows)
3. **Hydra Admin:** http://localhost:4445
4. **Kratos Admin:** http://localhost:4434

### Common Issues

1. **Certificate Trust Issues:**
   - Ensure your self-signed CA is properly configured in Hydra and Oathkeeper
   - Check certificate chain validation

2. **JWT Validation Errors:**
   - Verify JWT signature algorithm matches Hydra configuration
   - Check issuer and audience claims

3. **Permission Denied:**
   - Verify Keto relationships are properly set up
   - Check Oathkeeper access rules match your API paths

## Enhanced PKI Infrastructure (CRL/OCSP)

The Ory ecosystem now includes an enhanced PKI infrastructure with Certificate Revocation Lists (CRLs) and Online Certificate Status Protocol (OCSP) support for real-time certificate validation.

### PKI Architecture

```
                    ┌─────────────────┐
                    │   Root CA       │
                    │ book-looker-ca  │
                    └─────────┬───────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
     ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
     │   Server    │  │   Client    │  │    OCSP     │
     │    Cert     │  │    Cert     │  │ Responder   │
     │ (localhost) │  │(book-looker │  │    Cert     │
     └─────────────┘  │  -client)   │  └─────────────┘
                      └─────────────┘
```

### Certificate Extensions

All certificates include:
- **CRL Distribution Points**: `http://localhost:8080/crl/ca.crl`
- **OCSP Endpoints**: `http://localhost:8080/ocsp`
- **CA Certificate Distribution**: `http://localhost:8080/ca/ca.crt`

### PKI Services

The deployment includes dedicated PKI services:

1. **PKI HTTP Service** (port 8080):
   - Serves CRL files
   - Distributes CA certificates
   - Provides health checks

2. **OCSP Responder** (port 8081):
   - Real-time certificate status validation
   - Responds to OCSP requests
   - Integrated with CA database

### Certificate Management Commands

```bash
# Generate initial certificates with CRL/OCSP support
cd deploys/ory-ecosystem && ./setup.sh

# Test certificate chain validation
openssl verify -CAfile certs/ca.crt certs/server.crt

# Check OCSP response
openssl ocsp -issuer certs/ca.crt -cert certs/server.crt \
  -url http://localhost:8080/ocsp -noverify

# View certificate extensions
openssl x509 -in certs/server.crt -text -noout | grep -A5 "Authority Information Access"
```

### PKI Directory Structure

```
certs/
├── ca/                 # CA database files
│   ├── index.txt       # Certificate database
│   ├── serial          # Serial number tracking
│   └── crlnumber       # CRL serial numbers
├── crl/                # Certificate Revocation Lists
│   └── ca.crl          # Current CRL
├── ocsp/               # OCSP responder certificates
│   └── ocsp.crt        # OCSP signing certificate
├── issued/             # Issued certificates (CA managed)
├── private/            # Private keys (secure)
├── newcerts/           # Newly issued certificates
├── ca.crt              # Root CA certificate
├── server.crt          # Server certificate (with CRL/OCSP)
└── client.crt          # Client certificate
```

### Integration with Ory Services

All Ory services are configured to trust the CA and can validate certificates using:
- CRL checking for revoked certificates
- OCSP validation for real-time status
- Certificate chain validation

## Production Considerations

1. **Secrets Management:**
   - Use proper secret management for production
   - Rotate OAuth2 client secrets regularly

2. **Database:**
   - Use managed PostgreSQL service
   - Configure proper backup and replication

3. **TLS/SSL:**
   - Use proper SSL certificates (not self-signed)
   - Configure HTTPS for all endpoints

4. **PKI Management:**
   - Deploy OCSP responder in high availability setup
   - Configure CRL update scheduling
   - Implement certificate lifecycle management
   - Monitor certificate expiration dates

5. **Monitoring:**
   - Set up proper logging and monitoring
   - Configure alerts for authentication failures
   - Monitor PKI service health

6. **Performance:**
   - Consider token caching strategies
   - Optimize database queries for permission checks
   - Cache CRL and OCSP responses appropriately

## Next Steps

1. Deploy kerby-instruments service
2. Configure your Spring Boot application
3. Implement client applications with OAuth2 flows
4. Set up production-ready certificates with proper CA
5. Configure monitoring and alerting
6. Implement certificate lifecycle management

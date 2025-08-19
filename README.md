# Book looker Realm
Text and metadata (file contents and archive), detection and extraction pipeline, with catalog services, Go terminal-UI and JavaFX UI (mobile and desktop) in an own Kerberos realm.



![book-looker-realm](docs/book-looker-realm.png)

### Overview

**Kafka:**
- Kafka V3.3.8 Broker with SASL/GSSAPI authentication. (v4.0.0 support not released yet in [Spring for Apache Kafka](https://spring.io/projects/spring-kafka#support))

**Java Spring for Apache Kafka REST Web Service:**
- Spring Data MongoDB for data persistence, management, and search.
- User authentication with Kerberos with SSO (Single Sign-On) support.
- Oauth2 authorization support (resource server).
- Docs/Archive uploader management service (abstracting all S3 details).
- Data encryption and decryption service with gnupg (key pairs isolated for each user principal).
- Catalog management and update catalog tasks.
- Metadata management, relationships, and analysis.
- Search capabilities (catalog and metadatas).
- Translations (languages) service.
- Information templates management.
- Kafka client: Publisher. Use the user principal of the current logged user for authentication to Broker.

**[JavaFX](https://openjfx.io/)** Mobile and Desktop Client UI:
- User authentication with Kerberos with SSO (Single Sign-On) support.
- Client (GUI FrontEnd) for the Spring for Apache Kafka REST Web Service.
- JavaFX app in internet only (80/443) locations:
    - Authorization Code Flow (with mTLS or PKCE depending the X.509 user cert local availability in the client)
    - Client Credentials flow if we consider a mobile/desktop-server authentication (and the client cert is always available localy in the client).

**Golang Terminal User-Interface:**
- User authentication with Kerberos with SSO (Single Sign-On) support.
- Can be used in files batch process, automate tasks, or other integrations.

**Golang Subscriber worker:**
- Service authentication with Kerberos service principal.
- Kafka client: Subscriber. Always connect and authenticate to the Broker using his service principal.
- MinIO S3 client.
- Tika (sidecar) Server client: Extract text and metadata from files and handle all other Tika features.

**Ory ecosystem and Kerberos realm**
>
**kerby-instruments**: https://github.com/mesb/kerby-instruments
- Kerberos realm and principals management and integration with Ory ecosystem.
- X.509 user certificate management and self-signed PKI.
- Preauth mechanisms using JWT or PKI to request TGT and Service-Tickets.
- Realm constrained delegation based in users signed JWTs.
>
**Ory Hydra**: Golang OAuth2 and OpenID Connect provider for token-based authentication.
- kerby-instruments: Client Credentials.
- internet-only clients: Authorization Code Flow (with mTLS or PKCE depending the X.509 user cert local availability in the client). Maybe a Client Credentials flow if we consider a mobile/desktop-server authentication (and the client cert is always available localy in the client).
- OAuth2/OpenID Flows (MinIO and Spring for Apache Kafka REST Web Service).
>
**Ory Oathkeeper**: Golang Identity & Access Proxy / API (IAP) and Access Control Decision API.
- kerby-instruments: Client Credentials Flow. JWT mutations and proxying.
>
**Ory Kratos**: Golang Identity and User Management system with self-service flows.
- Principals and keys (users and services) management in the Kerby realm.
>
**Ory Keto**: Golang Fine-grained authorization server with relationship-based access control.
- Fine-grained authorization for the Spring for Apache Kafka REST Web Service.
- Fine-grained authorization for the S3 buckets (MinIO).

**Auth Overview**
![](/docs/auth_overview.png)

### Prerequisites
- Podman.
[Podman-kube](https://docs.podman.io/en/v5.0.3/markdown/podman-kube.1.html) is a prerequisite for create PODs based on Kubernetes.
This project uses sidecar containers and with Podman-kube the development environment is more similar to production.
- Go, Python and Java
- ...

## Tika Server
[**Documentation**](https://cwiki.apache.org/confluence/display/TIKA/TikaServer)

- **Extract Text from file (Tika detects the file type, including images using OCR)**: `POST http://localhost:9998/tika/form`
  - Content-Type: `multipart/form-data`
  - Accept: `text/plain`

- **Get Metadata (file and contents) from file**: `POST http://localhost:9998/meta/form`
  - Content-Type: `multipart/form-data`
  - Accept: `application/json`, `application/rdf+xml`, `text/csv`, `text/plain`

*Sample PDF files licensed under*: [**Creative Commons Attribution Share-alike 4.0**](https://creativecommons.org/licenses/by-sa/4.0/deed.en)
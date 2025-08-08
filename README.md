# Text and Metadata (file contents and archive), Detection and Extraction Pipeline with powerful web REST API catalog service in an own Kerberos realm.



![book-looker-realm](docs/book-looker-realm.png)

### Overview

**Kafka:**
- Kafka V3.3.8 Broker with SASL/GSSAPI authentication. (v4.0.0 support not released yet in [Spring for Apache Kafka](https://spring.io/projects/spring-kafka#support))

**Java Spring for Apache Kafka REST Web Service:**
- Spring Data MongoDB for data persistence, management, and search.
- User authentication with Kerberos with SSO (Single Sign-On) support.
- Oauth2 authorization support.
- Docs/Archive uploader management service (abstracting all S3 details).
- Catalog management and update catalog tasks.
- Metadata management, relationships, and analysis.
- Search capabilities (catalog and metadatas).
- Translations (languages) service.
- Information templates management.
- Kafka client: Publisher. Use the user principal of the current logged user for authentication to Broker.


**Python Qt Quick (QML/JavaScript) client GUI:**
- User authentication with Kerberos with SSO (Single Sign-On) support.
- Client (GUI FrontEnd) for the Spring for Apache Kafka REST Web Service.
- Qt Quick app in remote locations: Alternative ways to get Kerberos tickets, via JWT or OTP mechanisms.

**Golang Direct CLI:**
- User authentication with Kerberos with SSO (Single Sign-On) support.
- CLI without support to Spring for Apache Kafka REST Web Service.
- CLI with direct access to S3 buckets.
- Kafka client: Publisher. Always connect and authenticate to the Broker using the user principal (from current successfully logged user).
- Can be used in files batch process, automate tasks, or other integrations.

**Golang Subscriber worker:**
- Service authentication with Kerberos service principal.
- Kafka client: Subscriber. Always connect and authenticate to the Broker using his service principal.
- MinIO S3 client.
- Tika (sidecar) Server client: Extract text and metadata from files and handle all other Tika features.

**Kerby:**
- Java Lib with the implementation of the Kerberos protocol and a complete KDC(AS/TGS) server.
- Only Kerberos, not other protocol or service.
- KDC with: in-memory, Mavibot(MVCC BTree) or JSON backends to store data (principals and keys).
- Preauth mechanism using JWT or OTP mechanism to request TGT and Service-Tickets.
- SASL support and more.

**kerby-instruments**: https://github.com/mesb/kerby-instruments
- Java spring boot REST API for Apache Kerby.
- Remote Kerberos administration, instrumentation, metrics and telemetry.

**Ory ecosystem:**
>
**Ory Hydra**: Golang OAuth2 and OpenID Connect provider for token-based authentication.
- Alternative ways to get Kerberos tickets (via JWT or OTP).
- OAuth2/OpenID Flows (MinIO and Jakarta EE REST Web Service).
>
**Ory Kratos**: Golang Identity and User Management system with self-service flows.
- Principals and keys (users and services) management in the Kerby realm.
>
**Ory Keto**: Golang Fine-grained authorization server with relationship-based access control.
- Fine-grained authorization for the Jakarta EE REST Web Service.
- Fine-grained authorization for the S3 buckets (MinIO).

### Positive points about Kerberos

- **Service Session key** - Each client/server connection has its own session key, providing per-connection security (each Kerberos client connected to a MariaDB has its own session key, for example).
- **Mutual Authentication** - Both client and server verify each other's identity.
- **KDC Centralization** - In a Kerberos service/protocol/realm, only KDC servers have TCP/UDP listening ports (for Kerberos). When the client from a file-server or DB "kerberized" has aquired a service-ticket from a KDC using his valid TGT (to access the file-server or DB), the service-ticket is used in the authentication process\step from a given service\protocol (file-share or DB connection, for example).
- **Cross-Platform Support** - Widely supported across various operating systems and applications.
- **Strong Security** - Encrypted tickets and time-limited credentials.
- **Single Sign-On** - Principals authenticate once and gain access to multiple services without re-entering credentials.

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
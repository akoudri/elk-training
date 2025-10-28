# Secured ELK Stack Implementation Summary

This document summarizes the complete secured implementation of the ELK stack with automatic TLS certificate generation and RBAC support.

## What Was Created

### Core Files

1. **[docker-compose.secured.yml](docker-compose.secured.yml)** - Main secured compose file
   - Automatic certificate generation service (`create_certs`)
   - TLS-enabled Elasticsearch cluster (3 nodes)
   - Secured Kibana with SSL
   - Secured Logstash with authentication
   - Secured Filebeat with SSL
   - MinIO for snapshots
   - All communications encrypted

2. **[kibana.secured.yml](kibana.secured.yml)** - Kibana configuration
   - Server SSL enabled
   - Elasticsearch connection with SSL
   - Certificate authentication
   - Security and encryption keys configured

3. **[logstash/logstash.secured.yml](logstash/logstash.secured.yml)** - Logstash config
   - Monitoring with authentication
   - SSL certificate configuration

4. **[logstash/pipeline/logstash.secured.conf](logstash/pipeline/logstash.secured.conf)** - Pipeline
   - Elasticsearch output with SSL
   - Authentication configured

5. **[filebeat/filebeat.secured.yml](filebeat/filebeat.secured.yml)** - Filebeat config
   - SSL/TLS configuration
   - Authentication for Elasticsearch and Kibana

### Helper Scripts

1. **[start-secured.sh](start-secured.sh)** - Automated startup script
   - Validates configuration
   - Starts services in correct order
   - Waits for health checks
   - Displays connection information

2. **[extract-ca-cert.sh](extract-ca-cert.sh)** - Certificate extraction
   - Extracts CA certificate from container
   - Provides usage examples

### Documentation

1. **[SECURED-SETUP.md](SECURED-SETUP.md)** - Complete setup guide
   - Detailed instructions
   - Certificate management
   - RBAC configuration
   - Troubleshooting

2. **[SECURED-QUICK-REFERENCE.md](SECURED-QUICK-REFERENCE.md)** - Quick reference
   - Common commands
   - API examples
   - Troubleshooting tips

3. **[examples/rbac.txt](examples/rbac.txt)** - RBAC examples
   - Role creation patterns
   - User management
   - Permission examples
   - API keys
   - Field and document-level security

### Configuration Updates

1. **[.env](.env)** - Updated with security variables
   - `ELASTIC_PASSWORD` - Superuser password
   - `KIBANA_PASSWORD` - Kibana system user password

2. **[.gitignore](.gitignore)** - Updated to exclude certificates
   - CA certificates
   - Private keys
   - Other sensitive files

3. **[README.md](README.md)** - Updated with secured option
   - Two deployment options documented
   - Quick start for both versions

## Architecture Overview

### Certificate Generation Flow

```
1. create_certs service starts
   ↓
2. Generates CA certificate and key
   ↓
3. Creates certificates for:
   - es01, es02, es03 (Elasticsearch nodes)
   - kibana (Kibana server)
   ↓
4. Stores certificates in Docker volume 'certs'
   ↓
5. Sets proper permissions
   ↓
6. Other services start and mount the 'certs' volume
```

### Service Dependencies

```
create_certs (generates certs)
   ↓
es01, es02, es03 (use certs for TLS)
   ↓
kibana, logstash, filebeat (use certs to connect)
   ↓
setup (configures passwords and checks services)
```

### Volume Structure

```
certs/
├── ca/
│   ├── ca.crt          # Certificate Authority certificate
│   └── ca.key          # Certificate Authority private key
├── es01/
│   ├── es01.crt        # es01 node certificate
│   └── es01.key        # es01 node private key
├── es02/
│   ├── es02.crt
│   └── es02.key
├── es03/
│   ├── es03.crt
│   └── es03.key
└── kibana/
    ├── kibana.crt      # Kibana server certificate
    └── kibana.key      # Kibana server private key
```

## Security Features Implemented

### 1. Transport Layer Security (TLS/SSL)

- ✅ HTTP API encryption (client-to-node)
- ✅ Transport encryption (node-to-node)
- ✅ Automatic certificate generation
- ✅ Certificate-based verification
- ✅ Persistent certificate storage

### 2. Authentication

- ✅ Username/password authentication
- ✅ Built-in user accounts
- ✅ Configurable passwords via environment variables
- ✅ Support for custom users
- ✅ API key authentication support

### 3. Authorization (RBAC)

- ✅ Role-based access control enabled
- ✅ Built-in roles available
- ✅ Custom role creation support
- ✅ User-role mapping
- ✅ Index-level privileges
- ✅ Field-level security
- ✅ Document-level security

### 4. Monitoring

- ✅ X-Pack monitoring enabled
- ✅ Cluster health tracking
- ✅ Node metrics collection
- ✅ Audit logging capability (configurable)

### 5. Snapshot Repository

- ✅ MinIO S3-compatible storage
- ✅ Encrypted snapshot capability
- ✅ Snapshot lifecycle management support

## Key Differences: Secured vs Unsecured

| Aspect | Unsecured | Secured |
|--------|-----------|---------|
| **Protocol** | HTTP | HTTPS |
| **Authentication** | None | Required |
| **Certificates** | N/A | Auto-generated |
| **Setup Time** | ~1 minute | ~2-3 minutes |
| **Passwords** | N/A | Required in .env |
| **API Calls** | Simple curl | curl with auth |
| **Production Ready** | No | Yes (with proper passwords) |
| **RBAC** | No | Yes |
| **Audit Logging** | No | Yes (configurable) |

## Usage Examples

### Starting the Stack

```bash
# Unsecured
docker-compose up -d

# Secured
./start-secured.sh
```

### API Calls

```bash
# Unsecured
curl http://localhost:9200/_cluster/health?pretty

# Secured (with self-signed cert)
curl -k -u elastic:password https://localhost:9200/_cluster/health?pretty

# Secured (with CA cert)
curl --cacert ca.crt -u elastic:password https://localhost:9200/_cluster/health?pretty
```

### Accessing Kibana

```bash
# Unsecured
http://localhost:5601

# Secured
https://localhost:5601
Login: elastic / your_password
```

### Python Client

```python
# Unsecured
from elasticsearch import Elasticsearch
client = Elasticsearch(['http://localhost:9200'])

# Secured
from elasticsearch import Elasticsearch
client = Elasticsearch(
    ['https://localhost:9200'],
    basic_auth=('elastic', 'your_password'),
    ca_certs='./ca.crt'
)
```

## Environment Variables

Required in `.env` for secured setup:

| Variable | Purpose | Example |
|----------|---------|---------|
| `STACK_VERSION` | ELK version | 8.15.3 |
| `CLUSTER_NAME` | Cluster name | elk-training-cluster |
| `ELASTIC_PASSWORD` | Superuser password | StrongPassword123! |
| `KIBANA_PASSWORD` | Kibana system password | StrongPassword123! |
| `MINIO_ROOT_USER` | MinIO username | minioadmin |
| `MINIO_ROOT_PASSWORD` | MinIO password | minioadmin123 |

## Common Operations

### User Management

```bash
# List users
curl -k -u elastic:$PASS https://localhost:9200/_security/user

# Create user
curl -k -X POST https://localhost:9200/_security/user/myuser \
  -u elastic:$PASS -H "Content-Type: application/json" \
  -d '{"password":"pass","roles":["viewer"]}'

# Change password
curl -k -X POST https://localhost:9200/_security/user/myuser/_password \
  -u elastic:$PASS -H "Content-Type: application/json" \
  -d '{"password":"newpass"}'
```

### Role Management

```bash
# List roles
curl -k -u elastic:$PASS https://localhost:9200/_security/role

# Create role
curl -k -X PUT https://localhost:9200/_security/role/myrole \
  -u elastic:$PASS -H "Content-Type: application/json" \
  -d '{"cluster":["monitor"],"indices":[{"names":["myindex"],"privileges":["read"]}]}'
```

### Certificate Management

```bash
# Extract CA
./extract-ca-cert.sh

# View certificate details
openssl x509 -in ca.crt -text -noout

# Verify certificate chain
openssl verify -CAfile ca.crt node.crt
```

## Testing the Implementation

### 1. Basic Connectivity Test

```bash
./start-secured.sh
curl -k -u elastic:changeme https://localhost:9200?pretty
```

### 2. Authentication Test

```bash
# Should succeed
curl -k -u elastic:changeme https://localhost:9200/_security/_authenticate?pretty

# Should fail (401 Unauthorized)
curl -k https://localhost:9200?pretty
```

### 3. RBAC Test

```bash
# Create test role (read-only)
curl -k -X PUT https://localhost:9200/_security/role/test_role \
  -u elastic:changeme -H "Content-Type: application/json" \
  -d '{"indices":[{"names":["test"],"privileges":["read"]}]}'

# Create test user
curl -k -X POST https://localhost:9200/_security/user/testuser \
  -u elastic:changeme -H "Content-Type: application/json" \
  -d '{"password":"test123","roles":["test_role"]}'

# Test with limited user (should succeed)
curl -k -u testuser:test123 https://localhost:9200/test/_search

# Test write operation (should fail - no write privilege)
curl -k -X POST https://localhost:9200/test/_doc \
  -u testuser:test123 -H "Content-Type: application/json" \
  -d '{"field":"value"}'
```

### 4. TLS Certificate Test

```bash
# Extract CA
./extract-ca-cert.sh

# Test with CA (no -k needed)
curl --cacert ca.crt -u elastic:changeme https://localhost:9200?pretty
```

### 5. Kibana Access Test

1. Open https://localhost:5601
2. Accept self-signed certificate warning
3. Login with elastic / changeme
4. Navigate to Stack Monitoring
5. Verify cluster health visualization

## Maintenance Tasks

### Rotate Passwords

```bash
# 1. Update .env file with new passwords
# 2. Restart services
docker-compose -f docker-compose.secured.yml restart

# 3. Update kibana_system password
curl -k -X POST https://localhost:9200/_security/user/kibana_system/_password \
  -u elastic:NEW_PASS -H "Content-Type: application/json" \
  -d '{"password":"NEW_KIBANA_PASS"}'

# 4. Restart Kibana
docker-compose -f docker-compose.secured.yml restart kibana
```

### Regenerate Certificates

```bash
# 1. Stop all services
docker-compose -f docker-compose.secured.yml down

# 2. Remove certificate volume
docker volume rm elk-training_certs

# 3. Start again (certificates regenerate automatically)
./start-secured.sh
```

### Backup Certificates

```bash
# Extract all certificates
docker cp es01:/usr/share/elasticsearch/config/certs ./certs-backup

# Create archive
tar -czf certs-backup-$(date +%Y%m%d).tar.gz certs-backup/
```

## Troubleshooting

### Issue: Certificates Not Generated

**Check:**
```bash
docker-compose -f docker-compose.secured.yml logs create_certs
```

**Solution:**
```bash
docker-compose -f docker-compose.secured.yml down
docker volume rm elk-training_certs
./start-secured.sh
```

### Issue: Authentication Fails

**Check:**
```bash
# Verify password
cat .env | grep ELASTIC_PASSWORD

# Test authentication
curl -k -u elastic:PASSWORD https://localhost:9200/_security/_authenticate?pretty
```

**Solution:**
Update `.env` and restart services

### Issue: Kibana Won't Start

**Check:**
```bash
docker-compose -f docker-compose.secured.yml logs kibana
```

**Common causes:**
- Wrong KIBANA_PASSWORD in .env
- Elasticsearch not healthy yet
- Certificate issues

## Production Recommendations

Before using in production:

1. ✅ **Change all default passwords**
2. ✅ **Use strong, unique passwords (16+ characters)**
3. ✅ **Implement certificate rotation policy**
4. ✅ **Enable audit logging**
5. ✅ **Configure firewall rules**
6. ✅ **Set up regular backups**
7. ✅ **Monitor certificate expiration**
8. ✅ **Implement log retention policies**
9. ✅ **Review and harden security settings**
10. ✅ **Set up proper DNS for certificates**

## Additional Resources

- **Complete Setup Guide:** [SECURED-SETUP.md](SECURED-SETUP.md)
- **Quick Reference:** [SECURED-QUICK-REFERENCE.md](SECURED-QUICK-REFERENCE.md)
- **RBAC Examples:** [examples/rbac.txt](examples/rbac.txt)
- **Elasticsearch Security:** https://www.elastic.co/guide/en/elasticsearch/reference/current/secure-cluster.html
- **Kibana Security:** https://www.elastic.co/guide/en/kibana/current/using-kibana-with-security.html

## Support

For issues or questions:
1. Check [SECURED-SETUP.md](SECURED-SETUP.md) troubleshooting section
2. Review [examples/rbac.txt](examples/rbac.txt) for RBAC examples
3. Check Docker logs: `docker-compose -f docker-compose.secured.yml logs`
4. Review Elasticsearch documentation

## License

This secured implementation is part of the ELK training environment and is provided for educational purposes.

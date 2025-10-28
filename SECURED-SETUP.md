# Secured ELK Stack Setup Guide

This guide explains how to use the secured version of the ELK stack with TLS encryption and role-based access control (RBAC).

## Overview

The secured setup (`docker-compose.secured.yml`) provides:

1. **Automatic TLS Certificate Generation**: Certificates are generated automatically on first start
2. **Full Encryption**: All HTTP and transport communications are encrypted
3. **Authentication**: All services require username/password authentication
4. **RBAC Ready**: Built-in users configured, ready for custom role and user creation
5. **X-Pack Security**: Full security features enabled

## Quick Start

### 1. Configure Passwords

Edit [.env](.env) and set strong passwords:

```bash
ELASTIC_PASSWORD=your_secure_password_here
KIBANA_PASSWORD=your_secure_password_here
```

**Important**: Change these from the default `changeme` values!

### 2. Start the Secured Stack

```bash
./start-secured.sh
```

This script will:
- Generate TLS certificates automatically
- Start all services with security enabled
- Wait for the cluster to be healthy
- Display connection information

**First-time startup takes 2-3 minutes** for certificate generation.

### 3. Access the Services

**Elasticsearch API:**
```bash
curl -k -u elastic:YOUR_PASSWORD https://localhost:9200/_cluster/health?pretty
```

**Kibana Web UI:**
- Open: https://localhost:5601
- Accept the self-signed certificate warning
- Login: `elastic` / `YOUR_PASSWORD`

**MinIO Console:**
- Open: http://localhost:9001
- Login: `minioadmin` / `minioadmin123`

## Certificate Management

### Extract CA Certificate

For production-like API calls without `-k` (insecure) flag:

```bash
./extract-ca-cert.sh
```

This extracts the CA certificate to `./ca.crt`.

**Use with curl:**
```bash
curl --cacert ./ca.crt -u elastic:YOUR_PASSWORD https://localhost:9200/_cluster/health?pretty
```

**Use with Python:**
```python
from elasticsearch import Elasticsearch

client = Elasticsearch(
    ['https://localhost:9200'],
    basic_auth=('elastic', 'YOUR_PASSWORD'),
    ca_certs='./ca.crt'
)

print(client.info())
```

### Certificate Locations (inside containers)

- **CA Certificate**: `/usr/share/elasticsearch/config/certs/ca/ca.crt`
- **CA Private Key**: `/usr/share/elasticsearch/config/certs/ca/ca.key`
- **Node Certificates**: `/usr/share/elasticsearch/config/certs/{node_name}/{node_name}.crt`
- **Node Private Keys**: `/usr/share/elasticsearch/config/certs/{node_name}/{node_name}.key`

Certificates are stored in the Docker volume `certs` and persist across restarts.

### Regenerate Certificates

If you need to regenerate certificates:

```bash
# Stop all services
docker-compose -f docker-compose.secured.yml down

# Remove certificate volume
docker volume rm elk-training_certs

# Start again (certificates will be regenerated)
./start-secured.sh
```

## Role-Based Access Control (RBAC)

### Built-in Users

After starting the secured stack, these users are available:

| User | Password | Purpose |
|------|----------|---------|
| `elastic` | From .env | Superuser - full access |
| `kibana_system` | From .env | Kibana internal user |
| `logstash_system` | Auto-generated | Logstash internal user |
| `beats_system` | Auto-generated | Beats internal user |

### Create Custom Roles and Users

See [examples/rbac.txt](examples/rbac.txt) for comprehensive examples.

**Example: Create a read-only user for the titanic index**

```bash
# Create the role
curl -k -X PUT "https://localhost:9200/_security/role/titanic_reader" \
  -u elastic:YOUR_PASSWORD \
  -H "Content-Type: application/json" \
  -d '{
    "cluster": ["monitor"],
    "indices": [{
      "names": ["titanic"],
      "privileges": ["read", "view_index_metadata"]
    }]
  }'

# Create the user
curl -k -X POST "https://localhost:9200/_security/user/titanic_user" \
  -u elastic:YOUR_PASSWORD \
  -H "Content-Type: application/json" \
  -d '{
    "password": "titanic123",
    "roles": ["titanic_reader"],
    "full_name": "Titanic Reader"
  }'

# Test the user
curl -k -u titanic_user:titanic123 "https://localhost:9200/titanic/_search?pretty"
```

### Common Role Patterns

**Read-Only Analyst:**
```json
{
  "cluster": ["monitor"],
  "indices": [{
    "names": ["titanic", "temperatures"],
    "privileges": ["read", "view_index_metadata"]
  }]
}
```

**Data Writer (for applications):**
```json
{
  "cluster": ["monitor"],
  "indices": [{
    "names": ["logstash-*", "app-logs-*"],
    "privileges": ["write", "create_index", "auto_configure"]
  }]
}
```

**Backup Operator:**
```json
{
  "cluster": ["manage_slm", "cluster:admin/snapshot/*"],
  "indices": [{
    "names": ["*"],
    "privileges": ["all"]
  }]
}
```

## Kibana Access

### Login to Kibana

1. Open https://localhost:5601
2. Accept the self-signed certificate warning
3. Login with `elastic` user
4. Create additional users in Kibana UI:
   - **Management** → **Stack Management** → **Security** → **Users**

### Kibana Roles

Assign these built-in Kibana roles to users:

- `kibana_admin` - Full Kibana access
- `kibana_user` - Basic Kibana access (dashboards, discover)
- `viewer` - Read-only access to Kibana

## Data Ingestion with Authentication

### Update Python Scripts

Modify `pushES.py` to use authentication:

```python
from elasticsearch import Elasticsearch

client = Elasticsearch(
    ['https://localhost:9200'],
    basic_auth=('elastic', 'YOUR_PASSWORD'),
    verify_certs=False  # or ca_certs='./ca.crt' for production
)

# Now use client as normal
for i, doc in enumerate(data):
    client.index(index=index_name, id=i, document=doc)
```

### Using curl with Authentication

```bash
# Index data
curl -k -X POST "https://localhost:9200/myindex/_doc" \
  -u elastic:YOUR_PASSWORD \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}'

# Search data
curl -k -u elastic:YOUR_PASSWORD \
  "https://localhost:9200/myindex/_search?pretty"
```

## Snapshot Repository Setup

### Install S3 Plugin (Secured Version)

```bash
# Create installation script for secured environment
docker exec es01 bin/elasticsearch-plugin install --batch repository-s3
docker exec es02 bin/elasticsearch-plugin install --batch repository-s3
docker exec es03 bin/elasticsearch-plugin install --batch repository-s3

docker-compose -f docker-compose.secured.yml restart es01 es02 es03
```

### Configure Snapshot Repository

```bash
curl -k -X PUT "https://localhost:9200/_snapshot/my-snapshots" \
  -u elastic:YOUR_PASSWORD \
  -H "Content-Type: application/json" \
  -d '{
    "type": "s3",
    "settings": {
      "bucket": "elasticsearch-snapshots",
      "endpoint": "http://minio:9000",
      "protocol": "http",
      "path_style_access": true
    }
  }'
```

### Create and Restore Snapshots

```bash
# Create snapshot
curl -k -X PUT "https://localhost:9200/_snapshot/my-snapshots/backup_1?wait_for_completion=true" \
  -u elastic:YOUR_PASSWORD

# List snapshots
curl -k -u elastic:YOUR_PASSWORD \
  "https://localhost:9200/_snapshot/my-snapshots/_all?pretty"

# Restore snapshot
curl -k -X POST "https://localhost:9200/_snapshot/my-snapshots/backup_1/_restore" \
  -u elastic:YOUR_PASSWORD
```

## Monitoring

Access Stack Monitoring in Kibana:
1. Login to Kibana as `elastic` user
2. Navigate to **Management** → **Stack Monitoring**
3. View cluster health, node metrics, and index statistics

## Service Configuration Files

The secured setup uses these configuration files:

- **docker-compose.secured.yml** - Main compose file with TLS enabled
- **kibana.secured.yml** - Kibana configuration with SSL
- **logstash/logstash.secured.yml** - Logstash configuration with authentication
- **logstash/pipeline/logstash.secured.conf** - Pipeline with SSL output
- **filebeat/filebeat.secured.yml** - Filebeat configuration with SSL

## Troubleshooting

### Certificates Not Generated

Check the `create_certs` container logs:
```bash
docker-compose -f docker-compose.secured.yml logs create_certs
```

### Services Won't Start

Check individual service logs:
```bash
docker-compose -f docker-compose.secured.yml logs es01
docker-compose -f docker-compose.secured.yml logs kibana
```

### Authentication Failures

Verify the password in `.env` file:
```bash
cat .env | grep ELASTIC_PASSWORD
```

Test authentication:
```bash
curl -k -u elastic:YOUR_PASSWORD https://localhost:9200/_security/_authenticate?pretty
```

### Certificate Warnings in Browser

This is expected with self-signed certificates. Options:

1. **For testing**: Accept the security warning
2. **For production**: Use certificates from a trusted CA
3. **For development**: Add the CA certificate to your system's trusted store

### Reset Everything

Complete reset (WARNING: deletes all data):
```bash
docker-compose -f docker-compose.secured.yml down -v
./start-secured.sh
```

## Comparison: Secured vs Unsecured

| Feature | Unsecured (docker-compose.yml) | Secured (docker-compose.secured.yml) |
|---------|--------------------------------|--------------------------------------|
| Encryption | No | Yes (TLS) |
| Authentication | No | Yes (username/password) |
| Certificate Setup | N/A | Automatic |
| RBAC | No | Yes |
| Production Ready | No | Yes (with proper passwords) |
| Ease of Use | Very Easy | Medium |
| Use Case | Learning, Development | Training, Staging, Production |

## Security Best Practices

1. **Use Strong Passwords**: Never use default passwords in production
2. **Change Default Passwords**: Update `.env` before first start
3. **Limit User Privileges**: Follow principle of least privilege
4. **Use API Keys**: For programmatic access, prefer API keys over passwords
5. **Enable Audit Logging**: For compliance and security monitoring
6. **Rotate Credentials**: Regularly update passwords and API keys
7. **Use CA Certificates**: Avoid `-k` flag in production scripts
8. **Network Isolation**: Use Docker networks to isolate services
9. **Regular Backups**: Use snapshot repository for disaster recovery
10. **Monitor Access**: Review security logs regularly

## Next Steps

1. **Create Custom Roles**: See [examples/rbac.txt](examples/rbac.txt)
2. **Load Sample Data**: Use secured Python scripts
3. **Configure Snapshot Repository**: Set up automated backups
4. **Explore Kibana**: Create dashboards with different user roles
5. **Test Permissions**: Verify field and document-level security

## Additional Resources

- [Elasticsearch Security Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/secure-cluster.html)
- [Kibana Security](https://www.elastic.co/guide/en/kibana/current/using-kibana-with-security.html)
- [TLS/SSL Configuration](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-basic-setup-https.html)
- [Role-Based Access Control](https://www.elastic.co/guide/en/elasticsearch/reference/current/authorization.html)

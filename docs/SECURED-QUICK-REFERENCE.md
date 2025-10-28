# Secured ELK Stack - Quick Reference Card

## Start/Stop Commands

```bash
# Start secured stack
./start-secured.sh

# Stop secured stack
docker-compose -f docker-compose.secured.yml down

# Stop and remove all data
docker-compose -f docker-compose.secured.yml down -v

# View logs
docker-compose -f docker-compose.secured.yml logs -f

# Check status
docker-compose -f docker-compose.secured.yml ps
```

## Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Elasticsearch | https://localhost:9200 | elastic / (from .env) |
| Kibana | https://localhost:5601 | elastic / (from .env) |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin123 |

## Common API Calls

```bash
# Set password variable for convenience
export ES_PASS="your_password_here"

# Cluster health
curl -k -u elastic:$ES_PASS https://localhost:9200/_cluster/health?pretty

# List indices
curl -k -u elastic:$ES_PASS https://localhost:9200/_cat/indices?v

# List nodes
curl -k -u elastic:$ES_PASS https://localhost:9200/_cat/nodes?v

# Check authentication
curl -k -u elastic:$ES_PASS https://localhost:9200/_security/_authenticate?pretty
```

## Certificate Management

```bash
# Extract CA certificate
./extract-ca-cert.sh

# Use with CA cert (no -k flag needed)
curl --cacert ./ca.crt -u elastic:$ES_PASS https://localhost:9200/_cluster/health?pretty

# View certificate details
docker exec es01 openssl x509 -in /usr/share/elasticsearch/config/certs/es01/es01.crt -text -noout
```

## User Management

```bash
# Create a role
curl -k -X PUT "https://localhost:9200/_security/role/my_role" \
  -u elastic:$ES_PASS -H "Content-Type: application/json" \
  -d '{"cluster":["monitor"],"indices":[{"names":["myindex"],"privileges":["read"]}]}'

# Create a user
curl -k -X POST "https://localhost:9200/_security/user/myuser" \
  -u elastic:$ES_PASS -H "Content-Type: application/json" \
  -d '{"password":"userpass","roles":["my_role"]}'

# List all users
curl -k -u elastic:$ES_PASS https://localhost:9200/_security/user?pretty

# List all roles
curl -k -u elastic:$ES_PASS https://localhost:9200/_security/role?pretty

# Change user password
curl -k -X POST "https://localhost:9200/_security/user/myuser/_password" \
  -u elastic:$ES_PASS -H "Content-Type: application/json" \
  -d '{"password":"newpass"}'

# Delete user
curl -k -X DELETE "https://localhost:9200/_security/user/myuser" -u elastic:$ES_PASS
```

## Data Ingestion

```bash
# Index a document
curl -k -X POST "https://localhost:9200/myindex/_doc" \
  -u elastic:$ES_PASS -H "Content-Type: application/json" \
  -d '{"field":"value","timestamp":"2024-01-01T00:00:00"}'

# Bulk index
curl -k -X POST "https://localhost:9200/_bulk" \
  -u elastic:$ES_PASS -H "Content-Type: application/x-ndjson" \
  --data-binary @data.ndjson

# Search
curl -k -u elastic:$ES_PASS "https://localhost:9200/myindex/_search?pretty"
```

## Snapshot Management

```bash
# List repositories
curl -k -u elastic:$ES_PASS https://localhost:9200/_snapshot?pretty

# Create snapshot
curl -k -X PUT "https://localhost:9200/_snapshot/my-snapshots/snap1?wait_for_completion=true" \
  -u elastic:$ES_PASS

# List snapshots
curl -k -u elastic:$ES_PASS https://localhost:9200/_snapshot/my-snapshots/_all?pretty

# Restore snapshot
curl -k -X POST "https://localhost:9200/_snapshot/my-snapshots/snap1/_restore" \
  -u elastic:$ES_PASS

# Delete snapshot
curl -k -X DELETE "https://localhost:9200/_snapshot/my-snapshots/snap1" -u elastic:$ES_PASS
```

## Python Client

```python
from elasticsearch import Elasticsearch

# Without CA certificate (development)
client = Elasticsearch(
    ['https://localhost:9200'],
    basic_auth=('elastic', 'your_password'),
    verify_certs=False
)

# With CA certificate (production)
client = Elasticsearch(
    ['https://localhost:9200'],
    basic_auth=('elastic', 'your_password'),
    ca_certs='./ca.crt'
)

# Use client
print(client.info())
print(client.cluster.health())
```

## Troubleshooting

```bash
# View certificate creation logs
docker-compose -f docker-compose.secured.yml logs create_certs

# Check if certificates exist
docker exec es01 ls -la /usr/share/elasticsearch/config/certs/

# View Elasticsearch logs
docker-compose -f docker-compose.secured.yml logs es01

# View Kibana logs
docker-compose -f docker-compose.secured.yml logs kibana

# Restart a service
docker-compose -f docker-compose.secured.yml restart es01

# Force recreate certificates (WARNING: will require reconfiguration)
docker-compose -f docker-compose.secured.yml down
docker volume rm elk-training_certs
./start-secured.sh
```

## Security Best Practices

✅ **DO:**
- Change default passwords in `.env` before first start
- Use strong, unique passwords (16+ characters)
- Extract and use CA certificate for production scripts
- Create users with minimal required privileges
- Use API keys for application authentication
- Regularly rotate passwords and API keys
- Keep certificates secure and backed up

❌ **DON'T:**
- Use default `changeme` passwords in production
- Use `-k` flag in production scripts (insecure)
- Grant `superuser` role to application users
- Share passwords between users
- Commit `.env` file with real passwords to git
- Expose ports directly to internet without firewall

## File Locations

| File | Purpose |
|------|---------|
| `docker-compose.secured.yml` | Main secured compose file |
| `kibana.secured.yml` | Kibana configuration with TLS |
| `logstash/logstash.secured.yml` | Logstash configuration |
| `logstash/pipeline/logstash.secured.conf` | Logstash pipeline with auth |
| `filebeat/filebeat.secured.yml` | Filebeat configuration with TLS |
| `examples/rbac.txt` | RBAC examples and patterns |
| `SECURED-SETUP.md` | Complete setup documentation |
| `.env` | Environment variables and passwords |

## Quick Test Sequence

```bash
# 1. Start
./start-secured.sh

# 2. Extract CA
./extract-ca-cert.sh

# 3. Test connection
curl --cacert ./ca.crt -u elastic:$ES_PASS https://localhost:9200?pretty

# 4. Create test index
curl -k -X PUT "https://localhost:9200/test" -u elastic:$ES_PASS

# 5. Index document
curl -k -X POST "https://localhost:9200/test/_doc" \
  -u elastic:$ES_PASS -H "Content-Type: application/json" \
  -d '{"message":"Hello from secured ELK!"}'

# 6. Search
curl -k -u elastic:$ES_PASS "https://localhost:9200/test/_search?pretty"

# 7. Create user
curl -k -X POST "https://localhost:9200/_security/user/testuser" \
  -u elastic:$ES_PASS -H "Content-Type: application/json" \
  -d '{"password":"test123","roles":["viewer"]}'

# 8. Test new user
curl -k -u testuser:test123 "https://localhost:9200/test/_search?pretty"

# 9. Access Kibana
# Open: https://localhost:5601
# Login: elastic / your_password
```

## Environment Variables (.env)

```bash
STACK_VERSION=8.15.3
CLUSTER_NAME=elk-training-cluster
ELASTIC_PASSWORD=your_secure_password_here
KIBANA_PASSWORD=your_secure_password_here
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123
```

## Port Reference

| Port | Service | Protocol |
|------|---------|----------|
| 9200 | Elasticsearch REST API | HTTPS |
| 5601 | Kibana Web UI | HTTPS |
| 5044 | Logstash Beats input | TCP |
| 9600 | Logstash API | HTTP |
| 9000 | MinIO API | HTTP |
| 9001 | MinIO Console | HTTP |

## Additional Resources

- Full documentation: [SECURED-SETUP.md](SECURED-SETUP.md)
- RBAC examples: [examples/rbac.txt](examples/rbac.txt)
- Unsecured version: [docker-compose.yml](docker-compose.yml)
- General docs: [CLAUDE.md](CLAUDE.md)

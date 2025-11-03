# ELK Stack Training Environment

A complete Elasticsearch, Logstash, Kibana, and Filebeat (ELK + Beats) stack for learning and training purposes.

## Two Deployment Options

### 1. Unsecured (Easy Start - Learning)

- No authentication required
- No encryption
- Quick setup for experimentation
- **Use**: `docker-compose.yml`

### 2. Secured (Production-Like - Training)

- **Automatic TLS certificate generation**
- Full authentication and encryption
- Role-based access control (RBAC)
- **Use**: `docker-compose.secured.yml`
- **See**: [SECURED-SETUP.md](SECURED-SETUP.md) for details

## Features

- **3-node Elasticsearch cluster** for learning cluster concepts
- **X-Pack monitoring enabled** for cluster health and performance metrics
- **Kibana** for visualization and data exploration
- **Logstash** with multiple input methods (Beats, TCP, HTTP)
- **Filebeat** for log collection
- **MinIO** (S3-compatible storage) for snapshot/backup repository
- **Snapshot & Restore API** for backup and disaster recovery
- **TLS/SSL encryption** (secured version)
- **Role-based access control** (secured version)
- **Nginx log pipeline** - complete log flow demo (Nginx → Filebeat → Logstash → Elasticsearch)
- Sample datasets and query examples
- Python utilities for data ingestion

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM allocated to Docker
- Set `vm.max_map_count` for Elasticsearch (Linux only):
  ```bash
  sudo sysctl -w vm.max_map_count=262144
  ```

### Option A: Unsecured Stack (Easy Start)

0. Set System Config

```bash
   sudo sysctl -w vm.max_map_count=262144
```

1. Start all services:

   ```bash
   docker-compose up -d
   ```

2. Wait for services to be healthy (about 1-2 minutes):

   ```bash
   docker-compose ps
   ```

3. Verify cluster is running:

   ```bash
   curl http://localhost:9200/_cluster/health?pretty
   ```

4. Access Kibana:
   ```
   http://localhost:5601
   ```

### Option B: Secured Stack (Recommended for Training)

1. Configure passwords in `.env`:

   ```bash
   # Edit .env and set:
   ELASTIC_PASSWORD=your_secure_password
   KIBANA_PASSWORD=your_secure_password
   ```

2. Start the secured stack:

   ```bash
   ./start-secured.sh
   ```

3. Access services with authentication:

   ```bash
   # Elasticsearch (accept self-signed cert with -k)
   curl -k -u elastic:your_password https://localhost:9200/_cluster/health?pretty

   # Kibana (in browser)
   https://localhost:5601
   # Login: elastic / your_password
   ```

4. See [SECURED-SETUP.md](SECURED-SETUP.md) for complete documentation

### Load Sample Data

Install Python dependencies:

```bash
pip install -r requirements.txt
```

Load the Titanic dataset:

```bash
python pushES.py data/titanic.json titanic http://localhost:9200
```

Or use bulk loading for larger datasets:

```bash
python pushBulk.py data/shakespeare.ndjson shakespeare http://localhost:9200
```

### Test the Nginx Log Pipeline

The stack includes a complete Nginx log pipeline that automatically generates and processes web server logs.

1. **Automatic log generation** starts immediately (log_generator service)

2. **View logs in realtime:**

   ```bash
   # Watch nginx access logs
   docker exec nginx tail -f /var/log/nginx/access.log

   # Watch Filebeat collecting logs
   docker-compose logs -f filebeat | grep nginx

   # Watch Logstash processing logs
   docker-compose logs -f logstash | grep nginx
   ```

3. **Check data in Elasticsearch:**

   ```bash
   # View nginx indices
   curl "http://localhost:9200/_cat/indices/nginx-logs-*?v"

   # Count documents
   curl "http://localhost:9200/nginx-logs-*/_count?pretty"

   # View sample logs
   curl "http://localhost:9200/nginx-logs-*/_search?pretty&size=2"
   ```

4. **Visualize in Kibana:**
   - Open http://localhost:5601
   - Go to Discover
   - Create index pattern: `nginx-logs-*`
   - Set time field: `@timestamp`
   - Explore parsed and enriched logs with GeoIP and user agent data

**See [NGINX-LOG-PIPELINE.md](NGINX-LOG-PIPELINE.md) for complete documentation.**

### Test Other Log Inputs

1. Create an application log:

   ```bash
   echo "$(date) - Application started" >> logs/app.log
   ```

2. Send a test event to Logstash:

   ```bash
   curl -X POST -H "Content-Type: application/json" \
     -d '{"message": "Test event", "level": "info"}' \
     http://localhost:8080
   ```

3. View in Kibana:
   - Create index pattern: `logstash-*`

## Services and Ports

| Service        | Port | Description          |
| -------------- | ---- | -------------------- |
| Elasticsearch  | 9200 | REST API (es01 node) |
| Kibana         | 5601 | Web interface        |
| Logstash Beats | 5044 | Beats input          |
| Logstash TCP   | 5000 | TCP JSON input       |
| Logstash HTTP  | 8080 | HTTP JSON input      |
| Logstash API   | 9600 | Monitoring API       |
| MinIO API      | 9000 | S3-compatible API    |
| MinIO Console  | 9001 | Web management UI    |

## Directory Structure

```
.
├── data/                      # Sample datasets
├── requests/                  # Example Elasticsearch queries
├── logstash/                  # Logstash configuration
│   ├── logstash.yml
│   └── pipeline/
│       └── logstash.conf
├── filebeat/                  # Filebeat configuration
│   └── filebeat.yml
├── logs/                      # Application logs (monitored by Filebeat)
├── docker-compose.yml         # Docker services configuration
├── kibana.yml                 # Kibana configuration
├── .env                       # Environment variables
└── *.py                       # Python data ingestion utilities
```

## Python Utilities

- **pushES.py**: Index JSON array data to Elasticsearch
- **pushBulk.py**: Bulk index NDJSON data (faster for large datasets)
- **csv_to_json.py**: Convert CSV to JSON format

## Sample Datasets

- **titanic.json** (125KB): Titanic passenger data
- **temperatures.json** (51MB): Global temperature data
- **accounts.ndjson** (245KB): Banking account data
- **shakespeare.ndjson** (25MB): Shakespeare's works

## Example Queries

The `requests/` directory contains numerous query examples:

- `es-requests.txt`: Search queries (match, bool, range, etc.)
- `es-aggs.txt`: Aggregations (terms, avg, histogram, percentiles)
- `es-crud.txt`: CRUD operations
- `mappings.txt`: Index mapping definitions
- `templates.txt`: Index template examples
- `snapshots.txt`: Snapshot and restore operations

Copy queries from these files into Kibana Dev Tools Console.

## Snapshots and Backups

### Setup Snapshot Repository (One-time)

1. Install the S3 repository plugin:

   ```bash
   ./install-s3-plugin.sh
   ```

2. Configure the snapshot repository:
   ```bash
   ./setup-snapshot-repo.sh
   ```

### Create and Manage Snapshots

Create a snapshot:

```bash
curl -X PUT "http://localhost:9200/_snapshot/my-snapshots/backup_1?wait_for_completion=true"
```

List snapshots:

```bash
curl "http://localhost:9200/_snapshot/my-snapshots/_all?pretty"
```

Restore a snapshot:

```bash
curl -X POST "http://localhost:9200/_snapshot/my-snapshots/backup_1/_restore"
```

Access MinIO Console at http://localhost:9001 (user: `minioadmin`, pass: `minioadmin123`)

## Monitoring

Access Stack Monitoring in Kibana:

1. Open http://localhost:5601
2. Go to **Management** → **Stack Monitoring**
3. View cluster health, node metrics, and index statistics

X-Pack monitoring is pre-configured and collects metrics automatically.

## Cluster Management

Check cluster health:

```bash
curl http://localhost:9200/_cluster/health?pretty
```

View all nodes:

```bash
curl http://localhost:9200/_cat/nodes?v
```

View indices:

```bash
curl http://localhost:9200/_cat/indices?v
```

Stop the stack:

```bash
docker-compose down
```

Remove all data:

```bash
docker-compose down -v
```

## Configuration

The stack version is controlled in `.env`:

```bash
STACK_VERSION=8.15.3
CLUSTER_NAME=elk-training-cluster
```

To change versions, update `.env` and restart:

```bash
docker-compose down
docker-compose up -d
```

## Troubleshooting

View service logs:

```bash
docker-compose logs -f elasticsearch
docker-compose logs -f kibana
docker-compose logs -f logstash
docker-compose logs -f filebeat
```

Common issues:

1. **Out of memory**: Increase Docker memory limit to at least 4GB
2. **vm.max_map_count too low**: Run `sudo sysctl -w vm.max_map_count=262144`
3. **Services not starting**: Check logs with `docker-compose logs <service>`
4. **Cluster not forming**: Ensure all 3 ES nodes are healthy with `docker-compose ps`

## Documentation

See [CLAUDE.md](CLAUDE.md) for detailed architecture notes and advanced usage.

## Security Note

This setup has security disabled (xpack.security.enabled=false) for training purposes. **Do not use in production without enabling security features.**

## License

Training purposes only.

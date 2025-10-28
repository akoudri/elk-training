# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an Elasticsearch/Kibana (ELK Stack) training repository containing sample datasets, Python utilities for data ingestion, and example Elasticsearch query collections. The repository is designed for learning and practicing Elasticsearch operations, aggregations, and data analysis.

## Environment Setup

### Starting the ELK Stack

The stack uses official Elastic Docker images configured in [docker-compose.yml](docker-compose.yml) with a 3-node Elasticsearch cluster plus Kibana, Logstash, and Filebeat.

Start all services:
```bash
docker-compose up -d
```

Check cluster health:
```bash
curl http://localhost:9200/_cluster/health?pretty
```

View running services:
```bash
docker-compose ps
```

Stop all services:
```bash
docker-compose down
```

Remove all data volumes (WARNING: deletes all indexed data):
```bash
docker-compose down -v
```

### Services and Ports

- **Elasticsearch Cluster** (3 nodes):
  - es01: http://localhost:9200 (REST API)
  - es02: internal only
  - es03: internal only
- **Kibana**: http://localhost:5601
- **Logstash**:
  - Beats input: port 5044
  - TCP JSON input: port 5000
  - HTTP JSON input: port 8080
  - Monitoring API: port 9600
- **Filebeat**: (no exposed ports, sends to Logstash)
- **MinIO** (S3-compatible object storage):
  - API: http://localhost:9000
  - Console: http://localhost:9001 (Web UI)

### Elasticsearch Cluster Configuration

The cluster consists of 3 nodes (es01, es02, es03):
- Cluster name: `elk-training-cluster`
- Security disabled for training purposes (xpack.security.enabled=false)
- **X-Pack monitoring enabled** for cluster and node metrics visualization
- 512MB heap size per node (adjust in docker-compose.yml if needed)
- Each node has its own persistent volume (es-data01, es-data02, es-data03)
- Healthchecks enabled for proper startup ordering

**Monitoring Settings:**
- `xpack.monitoring.collection.enabled=true`: Enables monitoring data collection
- `xpack.monitoring.elasticsearch.collection.enabled=true`: Enables Elasticsearch-specific metrics

Access Stack Monitoring in Kibana at: http://localhost:5601 → Management → Stack Monitoring

### System Requirements

Before starting, ensure your system has:
- Docker memory limit increased (at least 4GB recommended)
- Set vm.max_map_count for Elasticsearch:
  ```bash
  # Linux
  sudo sysctl -w vm.max_map_count=262144

  # Make permanent (add to /etc/sysctl.conf)
  vm.max_map_count=262144

  # macOS/Windows Docker Desktop: Already configured by default
  ```

### Python Environment

Install Python dependencies:
```bash
pip install -r requirements.txt
```

Required packages:
- `simplejson==3.19.3`
- `elasticsearch==8.15.1`
- `pandas~=2.2.3`

## Data Ingestion Tools

### pushES.py - Index JSON Documents

Loads JSON array data and indexes documents individually to Elasticsearch.

Usage:
```bash
python pushES.py <json_file> <index_name> <elasticsearch_url>
```

Example:
```bash
python pushES.py data/titanic.json titanic http://localhost:9200
```

Notes:
- Expects JSON array format (list of objects)
- Each document receives a sequential ID (0, 1, 2, ...)
- Uses the official Elasticsearch Python client

### pushBulk.py - Bulk Index with NDJSON

Sends NDJSON (newline-delimited JSON) data to Elasticsearch using the Bulk API.

Usage:
```bash
python pushBulk.py <ndjson_file> <index_name> <elasticsearch_url>
```

Example:
```bash
python pushBulk.py data/shakespeare.ndjson shakespeare http://localhost:9200
```

Notes:
- Input must be NDJSON format (bulk API format)
- Uses raw HTTP requests rather than the Elasticsearch client
- More efficient for large datasets

### csv_to_json.py - CSV to JSON Converter

Converts CSV files to JSON array format for use with pushES.py.

Usage:
```bash
python csv_to_json.py <input_csv> <output_json>
```

## Sample Datasets

Located in the `data/` directory:

- **titanic.json**: Titanic passenger data (125KB) - suitable for testing queries, aggregations, and filtering
- **temperatures.json**: Global temperature data (51MB) - large dataset for performance testing and time-series analysis
- **accounts.ndjson**: Account/banking data (245KB) - NDJSON format for bulk indexing
- **shakespeare.ndjson**: Shakespeare's works (25MB) - NDJSON format, text analysis dataset

## Query Examples

The `requests/` directory contains Elasticsearch query examples organized by topic:

- **es-requests.txt**: Basic search queries (match, term, bool, range, query_string)
- **es-crud.txt**: CRUD operations (create, read, update, delete documents)
- **es-aggs.txt**: Aggregation examples (terms, avg, histogram, percentiles)
- **es-filtering.txt**: Filtering queries
- **mappings.txt**: Index mapping definitions with explicit field types
- **templates.txt**: Index templates for consistent mapping across multiple indices
- **temps-requests.txt**: Temperature dataset specific queries
- **temps-aggs.txt**: Temperature dataset aggregations
- **shakespear-requests.txt**: Shakespeare dataset queries
- **geosearch.txt**: Geospatial search examples
- **dynamic.txt**: Dynamic mapping examples
- **snapshots.txt**: Snapshot and restore operations, backup/recovery examples

These files contain raw Elasticsearch API requests (typically using Kibana Dev Tools console syntax with `GET`, `POST`, `PUT`, `DELETE` commands).

## Architecture Notes

### Data Flow

1. **CSV/Raw Data** -> csv_to_json.py -> **JSON Array**
2. **JSON Array** -> pushES.py -> **Elasticsearch Index** (individual documents)
3. **NDJSON** -> pushBulk.py -> **Elasticsearch Index** (bulk operation)
4. **Application Logs** -> Filebeat -> Logstash -> **Elasticsearch** -> Kibana

### Component Configurations

#### Elasticsearch Cluster

Three-node cluster configuration in [docker-compose.yml](docker-compose.yml):
- All nodes are master-eligible and data nodes
- Discovery via `discovery.seed_hosts` for cluster formation
- Security disabled for training (not for production use)
- Separate data volumes for each node

#### Kibana ([kibana.yml](kibana.yml))

- Connected to all 3 Elasticsearch nodes for load balancing
- Monitoring UI enabled for cluster visualization
- Console logging for debugging

#### Logstash

Configuration files:
- **[logstash/logstash.yml](logstash/logstash.yml)**: Main Logstash settings
- **[logstash/pipeline/logstash.conf](logstash/pipeline/logstash.conf)**: Pipeline configuration

Pipeline supports multiple inputs:
- **Beats input** (port 5044): Receives data from Filebeat
- **TCP input** (port 5000): JSON data over TCP
- **HTTP input** (port 8080): JSON data via HTTP POST

Output goes to all 3 Elasticsearch nodes with daily indices (pattern: `logstash-YYYY.MM.dd`)

Example to send data to Logstash via TCP:
```bash
echo '{"message": "test log", "level": "info"}' | nc localhost 5000
```

Example to send data via HTTP:
```bash
curl -X POST -H "Content-Type: application/json" -d '{"message": "test log"}' http://localhost:8080
```

#### Filebeat ([filebeat/filebeat.yml](filebeat/filebeat.yml))

Configured to collect:
- Docker container logs from `/var/lib/docker/containers`
- Application logs from `./logs/` directory (mounted as `/var/log/app`)
- Adds Docker metadata automatically

Outputs to Logstash on port 5044 (can be changed to direct Elasticsearch output)

To add application logs for Filebeat to collect:
```bash
# Add log files to the logs/ directory
echo "$(date) - Application started" >> logs/app.log
```

### MinIO Configuration

MinIO provides S3-compatible object storage for Elasticsearch snapshots.

Access the MinIO Console at http://localhost:9001:
- Username: `minioadmin` (from .env: MINIO_ROOT_USER)
- Password: `minioadmin123` (from .env: MINIO_ROOT_PASSWORD)

The MinIO API endpoint for Elasticsearch is `http://minio:9000` (internal network).

### Docker Setup

The docker-compose.yml uses official Elastic Docker images:
- `docker.elastic.co/elasticsearch/elasticsearch:8.15.3`
- `docker.elastic.co/kibana/kibana:8.15.3`
- `docker.elastic.co/logstash/logstash:8.15.3`
- `docker.elastic.co/beats/filebeat:8.15.3`
- `minio/minio:latest`

Version controlled via `.env` file (STACK_VERSION variable)

Persistent storage:
- `es-data01`, `es-data02`, `es-data03`: Elasticsearch node data volumes
- `minio-data`: MinIO object storage volume
- Configuration files mounted as read-only volumes

## Common Workflows

### Testing a New Query

1. Ensure ELK stack is running: `docker-compose up -d`
2. Index sample data: `python pushES.py data/titanic.json titanic http://localhost:9200`
3. Open Kibana Dev Tools: http://localhost:5601/app/dev_tools#/console
4. Reference query examples from `requests/` directory
5. Test and iterate on queries

### Working with Large Datasets

For large datasets like temperatures.json (51MB) or shakespeare.ndjson (25MB):
1. Convert to NDJSON format if needed (with bulk API action/metadata lines)
2. Use `pushBulk.py` instead of `pushES.py` for better performance
3. Consider creating index templates first (see `requests/templates.txt`)
4. Define explicit mappings to optimize storage and query performance

### Modifying Index Mappings

Elasticsearch mappings cannot be changed on existing indices. To apply new mappings:
1. Define mapping in a file (see `requests/mappings.txt` for examples)
2. Create a new index with the mapping: `PUT /new_index` with mapping definition
3. Reindex data: `POST _reindex` from old to new index, or re-run pushES.py/pushBulk.py

### Monitoring the Cluster

Check cluster health:
```bash
curl http://localhost:9200/_cluster/health?pretty
```

View nodes in the cluster:
```bash
curl http://localhost:9200/_cat/nodes?v
```

View all indices:
```bash
curl http://localhost:9200/_cat/indices?v
```

Or use Kibana Stack Monitoring:
1. Open Kibana: http://localhost:5601
2. Navigate to Stack Monitoring from the menu

### Testing the Full Pipeline

1. Start all services:
   ```bash
   docker-compose up -d
   ```

2. Wait for all services to be healthy (check with `docker-compose ps`)

3. Add a test log file:
   ```bash
   echo "$(date) - Test application log entry" >> logs/app.log
   ```

4. Send a test event to Logstash:
   ```bash
   curl -X POST -H "Content-Type: application/json" \
     -d '{"message": "Test from curl", "app": "test"}' \
     http://localhost:8080
   ```

5. View logs in Kibana:
   - Open http://localhost:5601
   - Go to Management > Stack Management > Index Management
   - Look for `logstash-*` indices
   - Create an index pattern and view in Discover

### Snapshot and Restore

Elasticsearch snapshots provide backup and disaster recovery capabilities.

#### Initial Setup (One-time)

1. Install the S3 repository plugin on all nodes:
   ```bash
   ./install-s3-plugin.sh
   ```

2. Configure the snapshot repository:
   ```bash
   ./setup-snapshot-repo.sh
   ```

   Or manually via API:
   ```bash
   curl -X PUT "http://localhost:9200/_snapshot/my-snapshots" \
     -H 'Content-Type: application/json' \
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

3. Create the bucket in MinIO (optional - will be created automatically):
   - Open http://localhost:9001
   - Login with credentials from .env
   - Create bucket named `elasticsearch-snapshots`

#### Creating Snapshots

Create a snapshot of all indices:
```bash
curl -X PUT "http://localhost:9200/_snapshot/my-snapshots/snapshot_1?wait_for_completion=true"
```

Create a snapshot of specific indices:
```bash
curl -X PUT "http://localhost:9200/_snapshot/my-snapshots/backup_titanic" \
  -H 'Content-Type: application/json' \
  -d '{
    "indices": "titanic",
    "ignore_unavailable": true,
    "include_global_state": false
  }'
```

#### Restoring Snapshots

Restore all indices from a snapshot:
```bash
curl -X POST "http://localhost:9200/_snapshot/my-snapshots/snapshot_1/_restore"
```

Restore with index renaming:
```bash
curl -X POST "http://localhost:9200/_snapshot/my-snapshots/snapshot_1/_restore" \
  -H 'Content-Type: application/json' \
  -d '{
    "indices": "titanic",
    "rename_pattern": "(.+)",
    "rename_replacement": "restored_$1"
  }'
```

#### Managing Snapshots

List all snapshots:
```bash
curl "http://localhost:9200/_snapshot/my-snapshots/_all?pretty"
```

Get snapshot status:
```bash
curl "http://localhost:9200/_snapshot/my-snapshots/snapshot_1/_status?pretty"
```

Delete a snapshot:
```bash
curl -X DELETE "http://localhost:9200/_snapshot/my-snapshots/snapshot_1"
```

See [requests/snapshots.txt](requests/snapshots.txt) for more examples including Snapshot Lifecycle Management (SLM).

### Monitoring the Stack

#### Access Stack Monitoring

1. Open Kibana: http://localhost:5601
2. Navigate to: **Management** → **Stack Monitoring**
3. If prompted, click "Turn on monitoring" (should be automatic with current config)

You can view:
- Cluster health and statistics
- Node performance metrics (CPU, memory, disk I/O)
- Index statistics and performance
- Shard allocation

#### X-Pack Monitoring Data

Monitoring data is stored in `.monitoring-*` indices. To view raw monitoring data:
```bash
curl "http://localhost:9200/.monitoring-es-*/_search?pretty"
```

#### Monitoring Metrics via API

Cluster stats:
```bash
curl "http://localhost:9200/_cluster/stats?pretty"
```

Node stats:
```bash
curl "http://localhost:9200/_nodes/stats?pretty"
```

Index stats:
```bash
curl "http://localhost:9200/_stats?pretty"
```

### Troubleshooting

View logs for specific service:
```bash
docker-compose logs -f elasticsearch
docker-compose logs -f kibana
docker-compose logs -f logstash
docker-compose logs -f filebeat
```

Restart a specific service:
```bash
docker-compose restart logstash
```

Check if Elasticsearch cluster formed correctly:
```bash
curl http://localhost:9200/_cat/nodes?v
# Should show 3 nodes: es01, es02, es03
```

# Quick Start Guide: Snapshots & Monitoring

This guide covers the new snapshot repository and monitoring features.

## Prerequisites

The ELK stack should be running:
```bash
docker-compose up -d
```

Wait for all services to be healthy:
```bash
docker-compose ps
```

## Setup Snapshot Repository (One-Time)

### Step 1: Install S3 Plugin

Run the installation script:
```bash
./install-s3-plugin.sh
```

This will:
- Install `repository-s3` plugin on all 3 Elasticsearch nodes
- Restart the cluster to load the plugin
- Verify the installation

**Note:** This takes about 2-3 minutes. The cluster will restart automatically.

### Step 2: Configure Snapshot Repository

Run the setup script:
```bash
./setup-snapshot-repo.sh
```

This creates a snapshot repository named `my-snapshots` that uses MinIO for storage.

**Verify the setup:**
```bash
curl http://localhost:9200/_snapshot/my-snapshots?pretty
```

## Using Snapshots

### Create Your First Snapshot

Snapshot all indices:
```bash
curl -X PUT "http://localhost:9200/_snapshot/my-snapshots/my-first-snapshot?wait_for_completion=true"
```

Snapshot specific indices:
```bash
curl -X PUT "http://localhost:9200/_snapshot/my-snapshots/titanic-backup" \
  -H 'Content-Type: application/json' \
  -d '{
    "indices": "titanic",
    "ignore_unavailable": true,
    "include_global_state": false
  }'
```

### List Snapshots

View all snapshots:
```bash
curl "http://localhost:9200/_snapshot/my-snapshots/_all?pretty"
```

Get details about a specific snapshot:
```bash
curl "http://localhost:9200/_snapshot/my-snapshots/my-first-snapshot?pretty"
```

### Restore from Snapshot

Restore all indices:
```bash
curl -X POST "http://localhost:9200/_snapshot/my-snapshots/my-first-snapshot/_restore"
```

Restore with a new name (won't conflict with existing):
```bash
curl -X POST "http://localhost:9200/_snapshot/my-snapshots/titanic-backup/_restore" \
  -H 'Content-Type: application/json' \
  -d '{
    "indices": "titanic",
    "rename_pattern": "titanic",
    "rename_replacement": "titanic-restored"
  }'
```

### Delete Snapshots

Remove old snapshots to free up storage:
```bash
curl -X DELETE "http://localhost:9200/_snapshot/my-snapshots/my-first-snapshot"
```

## MinIO Management Console

Access the MinIO web interface at http://localhost:9001

**Credentials:**
- Username: `minioadmin`
- Password: `minioadmin123`

In the console you can:
- Browse snapshot files in the `elasticsearch-snapshots` bucket
- Monitor storage usage
- Manage access policies

## Stack Monitoring

### Access Monitoring in Kibana

1. Open Kibana: http://localhost:5601
2. Click the menu icon (☰)
3. Navigate to: **Management** → **Stack Monitoring**

### What You Can Monitor

**Cluster Overview:**
- Cluster health status (green/yellow/red)
- Number of nodes, indices, documents
- Search and indexing rates
- Disk usage

**Nodes:**
- CPU, memory, and disk usage per node
- JVM heap statistics
- Network traffic

**Indices:**
- Index size and document count
- Search and indexing performance
- Shard allocation

### API-Based Monitoring

Check cluster health:
```bash
curl "http://localhost:9200/_cluster/health?pretty"
```

View node statistics:
```bash
curl "http://localhost:9200/_nodes/stats?pretty"
```

View cluster statistics:
```bash
curl "http://localhost:9200/_cluster/stats?pretty"
```

View index statistics:
```bash
curl "http://localhost:9200/_stats?pretty"
```

## Testing the Complete Workflow

### 1. Load Sample Data
```bash
python pushES.py data/titanic.json titanic http://localhost:9200
```

### 2. Create a Snapshot
```bash
curl -X PUT "http://localhost:9200/_snapshot/my-snapshots/titanic-test?wait_for_completion=true"
```

### 3. Delete the Index (simulate disaster)
```bash
curl -X DELETE "http://localhost:9200/titanic"
```

### 4. Verify Data is Gone
```bash
curl "http://localhost:9200/titanic/_search?pretty"
# Should return: index_not_found_exception
```

### 5. Restore from Snapshot
```bash
curl -X POST "http://localhost:9200/_snapshot/my-snapshots/titanic-test/_restore?wait_for_completion=true"
```

### 6. Verify Data is Restored
```bash
curl "http://localhost:9200/titanic/_count?pretty"
# Should show the original document count
```

### 7. Check Monitoring
Open Kibana Stack Monitoring to see the restore operation in the cluster activity.

## Automated Snapshots with SLM

Create a daily snapshot policy:
```bash
curl -X PUT "http://localhost:9200/_slm/policy/daily-snapshots" \
  -H 'Content-Type: application/json' \
  -d '{
    "schedule": "0 30 1 * * ?",
    "name": "<daily-snap-{now/d}>",
    "repository": "my-snapshots",
    "config": {
      "indices": ["*"],
      "ignore_unavailable": false,
      "include_global_state": false
    },
    "retention": {
      "expire_after": "30d",
      "min_count": 5,
      "max_count": 50
    }
  }'
```

Execute the policy immediately (for testing):
```bash
curl -X POST "http://localhost:9200/_slm/policy/daily-snapshots/_execute"
```

View SLM policies:
```bash
curl "http://localhost:9200/_slm/policy?pretty"
```

## Troubleshooting

### Plugin Installation Issues

If plugin installation fails, try installing manually on each node:
```bash
docker exec -it es01 bash
cd /usr/share/elasticsearch
bin/elasticsearch-plugin install repository-s3
exit

# Repeat for es02 and es03
docker-compose restart es01 es02 es03
```

### Repository Registration Fails

Check MinIO is running:
```bash
curl http://localhost:9000/minio/health/live
```

Verify the bucket exists in MinIO Console: http://localhost:9001

### Snapshots Are Slow

This is normal for large datasets. Use `?wait_for_completion=false` and check status:
```bash
curl "http://localhost:9200/_snapshot/my-snapshots/my-snapshot/_status?pretty"
```

### Monitoring Data Not Showing

Wait 1-2 minutes after starting the cluster for monitoring data to accumulate.

Verify monitoring is enabled:
```bash
curl "http://localhost:9200/_cluster/settings?include_defaults=true&filter_path=**.monitoring" | jq
```

## More Information

- See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation
- See [requests/snapshots.txt](requests/snapshots.txt) for more snapshot API examples
- Elasticsearch Snapshot API: https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshot-restore.html
- X-Pack Monitoring: https://www.elastic.co/guide/en/elasticsearch/reference/current/monitoring-overview.html

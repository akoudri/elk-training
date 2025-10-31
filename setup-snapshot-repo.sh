#!/bin/bash

# Setup script for Elasticsearch snapshot repository with MinIO
# This script configures Elasticsearch to use MinIO (S3-compatible) as a snapshot repository

set -e

ELASTICSEARCH_HOST="${1:-http://localhost:9200}"
MINIO_ENDPOINT="${2:-http://minio:9000}"
BUCKET_NAME="${3:-elasticsearch-snapshots}"
REPO_NAME="${4:-my-snapshots}"

echo "=== Elasticsearch Snapshot Repository Setup ==="
echo "Elasticsearch: $ELASTICSEARCH_HOST"
echo "MinIO Endpoint: $MINIO_ENDPOINT"
echo "Bucket Name: $BUCKET_NAME"
echo "Repository Name: $REPO_NAME"
echo ""

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch..."
until curl -s "$ELASTICSEARCH_HOST" > /dev/null 2>&1; do
  echo -n "."
  sleep 2
done
echo ""
echo "Elasticsearch is ready!"

# Check if repository-s3 plugin is installed
echo "Checking for repository-s3 plugin..."
PLUGIN_CHECK=$(curl -s "$ELASTICSEARCH_HOST/_cat/plugins" | grep -c "repository-s3" || true)

if [ "$PLUGIN_CHECK" -eq 0 ]; then
  echo ""
  echo "WARNING: repository-s3 plugin is not installed!"
  echo "To install the plugin, run the following on each Elasticsearch node:"
  echo ""
  echo "  docker exec es01 bin/elasticsearch-plugin install repository-s3"
  echo "  docker exec es02 bin/elasticsearch-plugin install repository-s3"
  echo "  docker exec es03 bin/elasticsearch-plugin install repository-s3"
  echo ""
  echo "Then restart the cluster:"
  echo "  docker-compose restart es01 es02 es03"
  echo ""
  exit 1
fi

echo "repository-s3 plugin is installed ✓"

# Configure S3 client settings with keystore (if not using security)
# For training without security, we'll use the repository settings directly

# Register the snapshot repository
echo ""
echo "Registering snapshot repository..."

curl -X PUT "$ELASTICSEARCH_HOST/_snapshot/$REPO_NAME" \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "s3",
    "settings": {
      "bucket": "'"$BUCKET_NAME"'",
      "endpoint": "'"$MINIO_ENDPOINT"'",
      "protocol": "http",
      "path_style_access": true
    }
  }'

echo ""
echo ""

# Verify the repository
echo "Verifying repository..."
curl -X POST "$ELASTICSEARCH_HOST/_snapshot/$REPO_NAME/_verify" | jq '.'

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To create a snapshot:"
echo "  curl -X PUT '$ELASTICSEARCH_HOST/_snapshot/$REPO_NAME/snapshot_1?wait_for_completion=true'"
echo ""
echo "To list snapshots:"
echo "  curl '$ELASTICSEARCH_HOST/_snapshot/$REPO_NAME/_all?pretty'"
echo ""
echo "To restore a snapshot:"
echo "  curl -X POST '$ELASTICSEARCH_HOST/_snapshot/$REPO_NAME/snapshot_1/_restore'"
echo ""

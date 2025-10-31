#!/bin/bash

# Extract CA certificate from the Elasticsearch container
# This allows you to make secure API calls without -k (insecure) flag

set -e

echo "=== Extracting CA Certificate ==="
echo ""

# Check if containers are running
if ! docker ps | grep -q es01; then
    echo "ERROR: es01 container is not running!"
    echo "Please start the secured stack first with: ./start-secured.sh"
    exit 1
fi

# Extract CA certificate
echo "Extracting CA certificate from es01 container..."
docker cp es01:/usr/share/elasticsearch/config/certs/ca/ca.crt ./ca.crt

if [ -f ca.crt ]; then
    echo "✓ CA certificate extracted successfully to ./ca.crt"
    echo ""
    echo "You can now use this certificate for secure API calls:"
    echo ""
    echo "Example:"
    echo "  curl --cacert ./ca.crt -u elastic:YOUR_PASSWORD https://localhost:9200/_cluster/health?pretty"
    echo ""
    echo "For Python scripts using the Elasticsearch client:"
    echo "  from elasticsearch import Elasticsearch"
    echo "  client = Elasticsearch("
    echo "      ['https://localhost:9200'],"
    echo "      basic_auth=('elastic', 'YOUR_PASSWORD'),"
    echo "      ca_certs='./ca.crt'"
    echo "  )"
    echo ""
else
    echo "ERROR: Failed to extract CA certificate"
    exit 1
fi

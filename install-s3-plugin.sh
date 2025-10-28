#!/bin/bash

# Install repository-s3 plugin on all Elasticsearch nodes
# Run this script after starting the cluster for the first time

set -e

echo "=== Installing repository-s3 plugin on all Elasticsearch nodes ==="
echo ""

echo "Installing on es01..."
docker exec es01 bin/elasticsearch-plugin install --batch repository-s3
echo "✓ Installed on es01"
echo ""

echo "Installing on es02..."
docker exec es02 bin/elasticsearch-plugin install --batch repository-s3
echo "✓ Installed on es02"
echo ""

echo "Installing on es03..."
docker exec es03 bin/elasticsearch-plugin install --batch repository-s3
echo "✓ Installed on es03"
echo ""

echo "=== Plugin installation complete ==="
echo ""
echo "Restarting Elasticsearch nodes to load the plugin..."
docker-compose restart es01 es02 es03

echo ""
echo "Waiting for cluster to be healthy..."
sleep 10

until curl -s http://localhost:9200/_cluster/health | grep -q "green\|yellow"; do
  echo -n "."
  sleep 2
done

echo ""
echo "✓ Cluster is healthy!"
echo ""
echo "Verifying plugin installation..."
curl -s http://localhost:9200/_cat/plugins | grep repository-s3

echo ""
echo ""
echo "=== Setup Complete ==="
echo "You can now configure the snapshot repository using:"
echo "  ./setup-snapshot-repo.sh"
echo ""

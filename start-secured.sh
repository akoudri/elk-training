#!/bin/bash

# Start the secured ELK stack with TLS and authentication

set -e

echo "=== Starting Secured ELK Stack ==="
echo ""

# Check vm.max_map_count (required for Elasticsearch)
CURRENT_MAP_COUNT=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
REQUIRED_MAP_COUNT=262144

if [ "$CURRENT_MAP_COUNT" -lt "$REQUIRED_MAP_COUNT" ]; then
    echo "ERROR: vm.max_map_count is too low ($CURRENT_MAP_COUNT)"
    echo "Elasticsearch requires vm.max_map_count to be at least $REQUIRED_MAP_COUNT"
    echo ""
    echo "To fix this, run:"
    echo "  sudo sysctl -w vm.max_map_count=$REQUIRED_MAP_COUNT"
    echo ""
    echo "To make it permanent across reboots, add this line to /etc/sysctl.conf:"
    echo "  vm.max_map_count=$REQUIRED_MAP_COUNT"
    echo ""
    exit 1
fi

echo "✓ vm.max_map_count is set correctly ($CURRENT_MAP_COUNT)"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    echo "Please create a .env file with the required variables."
    exit 1
fi

# Source the .env file
source .env

# Check if passwords are set
if [ "$ELASTIC_PASSWORD" == "changeme" ] || [ "$KIBANA_PASSWORD" == "changeme" ]; then
    echo "WARNING: You are using default passwords!"
    echo "It is recommended to change ELASTIC_PASSWORD and KIBANA_PASSWORD in .env file."
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Starting services with docker-compose.secured.yml..."
docker-compose -f docker-compose.secured.yml up -d

echo ""
echo "Waiting for services to start..."
echo "This may take 2-3 minutes for certificate generation and cluster formation."
echo ""

# Wait for certificate creation
echo "Step 1/4: Waiting for certificate generation..."
until docker-compose -f docker-compose.secured.yml ps | grep create_certs | grep -q "Exit 0"; do
    echo -n "."
    sleep 2
done
echo " ✓ Certificates created"

# Wait for Elasticsearch
echo "Step 2/4: Waiting for Elasticsearch cluster..."
sleep 10
until curl -s -k -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200/_cluster/health 2>&1 | grep -q "yellow\|green"; do
    echo -n "."
    sleep 5
done
echo " ✓ Elasticsearch is ready"

# Wait for Kibana
echo "Step 3/4: Waiting for Kibana..."
until curl -s -k -I https://localhost:5601/api/status 2>&1 | grep -q "200 OK"; do
    echo -n "."
    sleep 5
done
echo " ✓ Kibana is ready"

# Check all services
echo "Step 4/4: Checking all services..."
docker-compose -f docker-compose.secured.yml ps

echo ""
echo "=== Secured ELK Stack Started Successfully ==="
echo ""
echo "Services:"
echo "  - Elasticsearch: https://localhost:9200"
echo "  - Kibana: https://localhost:5601"
echo "  - MinIO Console: http://localhost:9001"
echo ""
echo "Credentials:"
echo "  - Elasticsearch user: elastic"
echo "  - Password: ${ELASTIC_PASSWORD}"
echo ""
echo "Certificate Authority (CA):"
echo "  - Location in container: /usr/share/elasticsearch/config/certs/ca/ca.crt"
echo "  - To extract CA: docker cp es01:/usr/share/elasticsearch/config/certs/ca/ca.crt ./ca.crt"
echo ""
echo "Testing connection:"
echo "  curl -k -u elastic:${ELASTIC_PASSWORD} https://localhost:9200/_cluster/health?pretty"
echo ""
echo "Or with CA certificate (after extracting):"
echo "  curl --cacert ./ca.crt -u elastic:${ELASTIC_PASSWORD} https://localhost:9200/_cluster/health?pretty"
echo ""
echo "Next steps:"
echo "  1. Access Kibana at https://localhost:5601 (accept self-signed certificate)"
echo "  2. Login with user 'elastic' and password '${ELASTIC_PASSWORD}'"
echo "  3. Create custom roles and users (see examples/rbac.txt)"
echo ""

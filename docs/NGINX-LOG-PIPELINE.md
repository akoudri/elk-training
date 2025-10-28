# Nginx Log Pipeline Guide

This guide explains the complete Nginx log collection, processing, and analysis pipeline added to the ELK stack.

## Overview

The Nginx log pipeline demonstrates a realistic data flow:

```
Nginx Web Server
    ↓ (generates logs)
Log Files (/var/log/nginx/*.log)
    ↓ (collected by)
Filebeat
    ↓ (sends to)
Logstash
    ↓ (parses & enriches)
Elasticsearch
    ↓ (visualized in)
Kibana
```

## Architecture Components

### 1. **Nginx Service**
- **Image**: `nginx:latest`
- **Purpose**: Web server generating access logs
- **Logs Location**: `/var/log/nginx/` (shared via Docker volume)
- **Log Format**: Combined Apache Log Format

### 2. **Log Generator Service**
- **Image**: `alpine:latest`
- **Purpose**: Simulates web traffic by sending HTTP requests
- **Frequency**: Every 3 seconds
- **Requests Generated**:
  - `GET /` (200 - Success)
  - `GET /index.html` (200 - Success)
  - `GET /nonexistent.html` (404 - Not Found)
  - `GET /api/users` (404 - Not Found)
  - `GET /admin` (404 - Not Found)

### 3. **Filebeat**
- **Purpose**: Collects logs from Nginx
- **Configuration**: [filebeat/filebeat.yml](filebeat/filebeat.yml)
- **Input**: `/var/log/nginx/*.log`
- **Output**: Logstash on port 5044

### 4. **Logstash**
- **Purpose**: Parses, enriches, and transforms logs
- **Configuration**: [logstash/pipeline/logstash.conf](logstash/pipeline/logstash.conf)
- **Processing**:
  - Grok parsing (COMBINEDAPACHELOG pattern)
  - GeoIP enrichment
  - User agent parsing
  - Error classification
  - URL path extraction
- **Output**: Elasticsearch index `nginx-logs-YYYY.MM.dd`

### 5. **Elasticsearch**
- **Purpose**: Stores and indexes logs
- **Index Pattern**: `nginx-logs-*`
- **Data**: Structured, enriched log documents

### 6. **Kibana**
- **Purpose**: Visualization and analysis
- **Access**: http://localhost:5601
- **Use Cases**: Dashboards, searches, analytics

## Quick Start

### 1. Start the Stack

```bash
# Start all services including nginx
docker-compose up -d

# Verify all services are running
docker-compose ps
```

### 2. Wait for Log Generation

The log_generator will start sending requests after about 30 seconds.

```bash
# Watch nginx logs being generated
docker exec nginx tail -f /var/log/nginx/access.log

# Watch filebeat collecting logs
docker-compose logs -f filebeat | grep nginx

# Watch logstash processing logs
docker-compose logs -f logstash | grep nginx
```

### 3. Verify Data in Elasticsearch

```bash
# Check if nginx-logs index exists
curl "http://localhost:9200/_cat/indices/nginx-logs-*?v"

# Count documents
curl "http://localhost:9200/nginx-logs-*/_count?pretty"

# View sample documents
curl "http://localhost:9200/nginx-logs-*/_search?pretty&size=2"
```

### 4. Visualize in Kibana

1. Open Kibana: http://localhost:5601
2. Navigate to **Management** → **Stack Management** → **Index Patterns**
3. Create index pattern: `nginx-logs-*`
4. Set time field: `@timestamp`
5. Go to **Discover** to explore logs

## Log Processing Pipeline

### Input (Filebeat)

**Raw Log Entry:**
```
172.18.0.8 - - [28/10/2024:15:30:45 +0000] "GET /nonexistent.html HTTP/1.1" 404 153 "-" "curl/8.9.1"
```

### Filter (Logstash)

**Grok Parsing:**
- Extracts: IP, timestamp, HTTP method, URL, status code, bytes, user agent

**Enrichments:**
1. **GeoIP Lookup**:
   - Adds country, city, location coordinates
   - Field: `geoip.*`

2. **User Agent Parsing**:
   - Browser name, OS, device type
   - Field: `user_agent.*`

3. **Error Classification**:
   - 404 → Tag: `not_found`, Field: `error_type: "not_found"`
   - 400-499 → Tag: `client_error`
   - 500-599 → Tag: `server_error`
   - 200-299 → Tag: `success`

4. **URL Parsing**:
   - HTTP method: `GET`, `POST`, etc.
   - URL path: `/api/users`
   - HTTP version: `1.1`

### Output (Elasticsearch)

**Structured Document:**
```json
{
  "@timestamp": "2024-10-28T15:30:45.000Z",
  "clientip": "172.18.0.8",
  "response": 404,
  "bytes": 153,
  "request": "GET /nonexistent.html HTTP/1.1",
  "http_method": "GET",
  "url_path": "/nonexistent.html",
  "http_version": "1.1",
  "agent": "curl/8.9.1",
  "log_type": "nginx",
  "service": "nginx",
  "error_type": "not_found",
  "tags": ["nginx", "web", "nginx_parsed", "not_found"],
  "geoip": {
    "location": { "lat": 37.7749, "lon": -122.4194 },
    "country_name": "United States",
    "city_name": "San Francisco"
  },
  "user_agent": {
    "name": "curl",
    "os": "Linux",
    "device": "Other"
  }
}
```

## Configuration Files

### docker-compose.yml Updates

Added services:
```yaml
nginx:
  image: nginx:latest
  volumes:
    - nginx_logs:/var/log/nginx
  networks:
    - elastic

log_generator:
  image: alpine:latest
  command: # Sends requests every 3 seconds
  depends_on:
    - nginx
    - es01

filebeat:
  volumes:
    - nginx_logs:/var/log/nginx:ro  # Added nginx logs volume
```

### filebeat/filebeat.yml

```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/nginx/*.log
    fields:
      log_type: nginx
      service: nginx
    fields_under_root: true
    tags: ["nginx", "web"]

output.logstash:
  hosts: ["logstash:5044"]
```

### logstash/pipeline/logstash.conf

Key filter sections:
```ruby
filter {
  if [log_type] == "nginx" or "nginx" in [tags] {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
    geoip {
      source => "clientip"
      target => "geoip"
    }
    useragent {
      source => "agent"
      target => "user_agent"
    }
    # Error classification logic
    # URL parsing
  }
}

output {
  elasticsearch {
    hosts => ["http://es01:9200", ...]
    index => "nginx-logs-%{+YYYY.MM.dd}"
  }
}
```

## Useful Queries

### Count by Response Code

```json
GET nginx-logs-*/_search
{
  "size": 0,
  "aggs": {
    "status_codes": {
      "terms": {
        "field": "response"
      }
    }
  }
}
```

### Find All 404 Errors

```json
GET nginx-logs-*/_search
{
  "query": {
    "term": {
      "response": 404
    }
  }
}
```

### Count by URL Path

```json
GET nginx-logs-*/_search
{
  "size": 0,
  "aggs": {
    "top_urls": {
      "terms": {
        "field": "url_path.keyword",
        "size": 10
      }
    }
  }
}
```

### Traffic by Country (GeoIP)

```json
GET nginx-logs-*/_search
{
  "size": 0,
  "aggs": {
    "by_country": {
      "terms": {
        "field": "geoip.country_name.keyword"
      }
    }
  }
}
```

### Time Series Analysis

```json
GET nginx-logs-*/_search
{
  "size": 0,
  "aggs": {
    "requests_over_time": {
      "date_histogram": {
        "field": "@timestamp",
        "calendar_interval": "1m"
      },
      "aggs": {
        "avg_response_code": {
          "avg": {
            "field": "response"
          }
        }
      }
    }
  }
}
```

### Browser Statistics

```json
GET nginx-logs-*/_search
{
  "size": 0,
  "aggs": {
    "browsers": {
      "terms": {
        "field": "user_agent.name.keyword"
      }
    }
  }
}
```

## Kibana Dashboards

### Creating a Basic Dashboard

1. **Navigate to Dashboard**:
   - Open Kibana → Dashboard → Create dashboard

2. **Add Visualizations**:

   **A. Response Codes Pie Chart**
   - Visualization type: Pie
   - Metrics: Count
   - Buckets: Terms aggregation on `response`

   **B. Requests Timeline**
   - Visualization type: Line
   - Y-axis: Count
   - X-axis: Date histogram on `@timestamp`

   **C. Top URLs Table**
   - Visualization type: Data Table
   - Metrics: Count
   - Rows: Terms on `url_path.keyword`

   **D. Geographic Map**
   - Visualization type: Maps
   - Layer: Documents
   - Field: `geoip.location`

   **E. Error Rate Gauge**
   - Visualization type: Gauge
   - Filter: `tags: "not_found"`
   - Show percentage of 404s

3. **Save Dashboard**:
   - Name: "Nginx Access Logs"
   - Add time range selector

### Saved Searches

Create useful searches:

**404 Errors:**
```
tags: "not_found" OR response: 404
```

**Server Errors:**
```
tags: "server_error" OR (response >= 500 AND response < 600)
```

**Successful Requests:**
```
tags: "success" OR (response >= 200 AND response < 300)
```

## Index Lifecycle Management (ILM)

Apply ILM policy for automatic index management:

```bash
# Create ILM policy (see requests/nginx-ilm.txt)
curl -X PUT "http://localhost:9200/_ilm/policy/nginx-logs-policy" \
  -H "Content-Type: application/json" \
  -d @ilm-policy.json

# Apply to index template
curl -X PUT "http://localhost:9200/_index_template/nginx-logs-template" \
  -H "Content-Type: application/json" \
  -d @index-template.json
```

**ILM Phases:**
- **Hot** (0-7 days): Active indexing, rollover daily
- **Warm** (7-30 days): Read-only, force merge, shrink
- **Cold** (30-90 days): Rarely accessed
- **Delete** (90+ days): Automatically deleted

## Troubleshooting

### No Logs Appearing in Elasticsearch

**Check Nginx is generating logs:**
```bash
docker exec nginx ls -la /var/log/nginx/
docker exec nginx tail /var/log/nginx/access.log
```

**Check Filebeat is collecting:**
```bash
docker-compose logs filebeat | grep nginx
```

**Check Logstash is processing:**
```bash
docker-compose logs logstash | grep -A 5 -B 5 nginx
```

**Check Elasticsearch indices:**
```bash
curl "http://localhost:9200/_cat/indices/nginx-logs-*?v"
```

### Grok Parse Failures

View parsing failures:
```bash
GET nginx-logs-*/_search
{
  "query": {
    "term": {
      "tags": "_grokparsefailure_nginx"
    }
  }
}
```

**Solution**: Check log format matches COMBINEDAPACHELOG pattern

### GeoIP Not Working

GeoIP enrichment requires the GeoIP database. If not present:
```bash
# Check if geoip fields exist
GET nginx-logs-*/_search
{
  "query": {"exists": {"field": "geoip"}}
}
```

**Note**: Internal/private IPs (like 172.x.x.x) won't have GeoIP data.

### Performance Issues

If indexing is slow:

1. **Increase Logstash workers:**
   ```yaml
   environment:
     - "LS_JAVA_OPTS=-Xms512m -Xmx512m"
   ```

2. **Batch Filebeat sends:**
   ```yaml
   # In filebeat.yml
   output.logstash:
     hosts: ["logstash:5044"]
     bulk_max_size: 2048
   ```

3. **Adjust Elasticsearch refresh interval:**
   ```bash
   PUT nginx-logs-*/_settings
   {
     "index": {
       "refresh_interval": "30s"
     }
   }
   ```

## Testing the Pipeline

### Generate Custom Traffic

```bash
# Access the nginx container
docker exec -it nginx bash

# Or generate traffic from your host
for i in {1..100}; do
  curl -s http://localhost > /dev/null
  curl -s http://localhost/test.html > /dev/null
done
```

### Validate Pipeline

```bash
# 1. Check log generation
docker exec nginx tail -20 /var/log/nginx/access.log

# 2. Verify Filebeat is reading
docker-compose logs --tail=50 filebeat

# 3. Check Logstash processing
docker-compose logs --tail=50 logstash

# 4. Query Elasticsearch
curl "http://localhost:9200/nginx-logs-*/_search?size=5&pretty"

# 5. View in Kibana Discover
# Open http://localhost:5601/app/discover
```

## Advanced Features

### Custom Nginx Log Format

To use custom log formats, update Logstash grok pattern:

```ruby
# In logstash.conf
grok {
  match => { "message" => "YOUR_CUSTOM_PATTERN" }
}
```

### Add Custom Fields

```ruby
# In logstash.conf filter
mutate {
  add_field => {
    "environment" => "production"
    "application" => "web"
  }
}
```

### Alerting

Create alerts in Kibana for:
- High error rate (>10% 4xx/5xx)
- Spike in traffic
- Geographic anomalies
- Specific URL patterns

## Production Recommendations

1. **Use ILM**: Automatically manage index lifecycle
2. **Enable Security**: Use the secured docker-compose version
3. **Optimize Mappings**: Define explicit field types
4. **Monitor Performance**: Watch Logstash and Filebeat metrics
5. **Set Retention Policy**: Delete old indices automatically
6. **Use Index Aliases**: For seamless index rotation
7. **Enable Monitoring**: Use X-Pack monitoring
8. **Backup Regularly**: Use snapshot repository

## Additional Resources

- **ILM Configuration**: [requests/nginx-ilm.txt](requests/nginx-ilm.txt)
- **Grok Patterns**: https://github.com/logstash-plugins/logstash-patterns-core
- **GeoIP Filter**: https://www.elastic.co/guide/en/logstash/current/plugins-filters-geoip.html
- **Filebeat Modules**: https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-modules.html

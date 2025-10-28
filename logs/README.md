# Logs Directory

This directory is monitored by Filebeat for collecting application logs.

## Usage

Add any `.log` files to this directory and Filebeat will automatically collect them and send them to Logstash.

Example:
```bash
echo "$(date) - Application started successfully" >> logs/app.log
echo "$(date) - User login successful" >> logs/app.log
```

The logs will be:
1. Collected by Filebeat
2. Sent to Logstash (port 5044)
3. Processed and indexed in Elasticsearch
4. Viewable in Kibana under the `logstash-*` index pattern

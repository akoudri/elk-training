import requests
import sys


def send_bulk_data_to_elasticsearch(file_path, index_name, es_host='http://localhost:9200'):
    # Read bulk data from file
    with open(file_path, 'r') as f:
        bulk_data = f.read()

    # Define the Elasticsearch bulk API endpoint
    url = f'{es_host}/{index_name}/_bulk'

    # Send the bulk data to the Elasticsearch endpoint
    headers = {'Content-Type': 'application/x-ndjson'}
    response = requests.post(url, data=bulk_data, headers=headers)

    # Check for success
    if response.status_code == 200:
        print('Data successfully indexed!')
    else:
        print(f'Error: {response.status_code} - {response.text}')


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python pushBulk.py <bulk_data_file> <index_name> <es_host>")
        sys.exit(1)

    bulk_data_file = sys.argv[1]
    index_name = sys.argv[2]
    es_host = sys.argv[3]
    send_bulk_data_to_elasticsearch(bulk_data_file, index_name, es_host)
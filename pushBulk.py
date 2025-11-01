import requests
import sys


def send_bulk_data_to_elasticsearch(file_path, index_name, es_host='http://localhost:9200', batch_size=1000):
    # Define the Elasticsearch bulk API endpoint
    url = f'{es_host}/{index_name}/_bulk'
    headers = {'Content-Type': 'application/x-ndjson'}

    # Read and process data in batches
    with open(file_path, 'r') as f:
        lines = []
        total_docs = 0
        batch_num = 0

        for line in f:
            lines.append(line)
            # Each document in NDJSON format has 2 lines (metadata + data)
            if len(lines) >= batch_size * 2:
                batch_num += 1
                bulk_data = ''.join(lines)
                response = requests.post(url, data=bulk_data, headers=headers)

                if response.status_code == 200:
                    docs_in_batch = len(lines) // 2
                    total_docs += docs_in_batch
                    print(f'Batch {batch_num}: {docs_in_batch} documents indexed successfully')
                else:
                    print(f'Error in batch {batch_num}: {response.status_code} - {response.text}')
                    return

                lines = []

        # Send remaining lines
        if lines:
            batch_num += 1
            bulk_data = ''.join(lines)
            response = requests.post(url, data=bulk_data, headers=headers)

            if response.status_code == 200:
                docs_in_batch = len(lines) // 2
                total_docs += docs_in_batch
                print(f'Batch {batch_num}: {docs_in_batch} documents indexed successfully')
            else:
                print(f'Error in batch {batch_num}: {response.status_code} - {response.text}')
                return

    print(f'\nTotal: {total_docs} documents successfully indexed!')


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python pushBulk.py <bulk_data_file> <index_name> <es_host>")
        sys.exit(1)

    bulk_data_file = sys.argv[1]
    index_name = sys.argv[2]
    es_host = sys.argv[3]
    send_bulk_data_to_elasticsearch(bulk_data_file, index_name, es_host)
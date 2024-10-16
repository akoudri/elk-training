import pandas as pd
import json
import sys


def csv_to_json(csv_file_path, json_file_path):
    # Read the CSV file
    df = pd.read_csv(csv_file_path)
    df.dropna(axis=0, inplace=True)

    # Convert the dataframe to a list of dictionaries
    records = df.to_dict(orient='records')

    # Write the JSON file
    with open(json_file_path, 'w', encoding='utf-8') as f:
        json.dump(records, f, ensure_ascii=False, indent=4)

    print(f"Successfully converted {csv_file_path} to {json_file_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_csv_file> <output_json_file>")
        sys.exit(1)

    input_csv = sys.argv[1]
    output_json = sys.argv[2]

    csv_to_json(input_csv, output_json)
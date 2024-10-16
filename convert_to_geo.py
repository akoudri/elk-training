import json
import sys


def transform_json(input_file, output_file):
    with open(input_file, 'r') as f:
        data = json.load(f)

    transformed_data = []
    for item in data:
        # Extraire les valeurs de latitude et longitude
        lat = float(item['Latitude'].rstrip('N').rstrip('S'))
        lon = float(item['Longitude'].rstrip('W').rstrip('E'))

        # Ajuster la longitude si elle est ouest (W)
        if 'W' in item['Longitude']:
            lon = -lon

        # Créer le nouveau document avec le champ location
        new_item = item.copy()
        new_item['location'] = {
            "lat": lat,
            "lon": lon
        }

        # Supprimer les anciens champs de latitude et longitude si nécessaire
        del new_item['Latitude']
        del new_item['Longitude']

        transformed_data.append(new_item)

    with open(output_file, 'w') as f:
        json.dump(transformed_data, f, indent=2)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py input_file.json output_file.json")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    transform_json(input_file, output_file)
    print(f"Transformation terminée. Résultat sauvegardé dans {output_file}")
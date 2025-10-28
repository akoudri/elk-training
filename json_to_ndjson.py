import pandas as pd

# Lire le fichier JSON
df = pd.read_json('data/temperatures.json')

# Écrire le fichier NDJSON
df.to_json('data/temperatures.ndjson', orient='records', lines=True)



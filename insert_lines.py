def insert_index_line(input_file, output_file):
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            # Écrire la ligne {"index":{}} avant chaque ligne
            outfile.write('{"index":{}}\n')
            # Écrire la ligne originale
            outfile.write(line)


# Exemple d'utilisation
input_file = 'data/temperatures.ndjson'
output_file = 'data/temperatures.ndjson'
insert_index_line(input_file, output_file)
print(f"Traitement terminé. Résultat sauvegardé dans {output_file}")
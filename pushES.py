import sys
from os.path import isfile
import simplejson as json
from elasticsearch import Elasticsearch
import re


def pushES(file, index, url):
    if isfile(file) == False or file.endswith('.json') == False:
        return
    regex = re.compile(r'\w{2,}')
    if re.fullmatch(regex, index) is None:
        return
    regex = re.compile(
        r'^(?:http)s?://' # http:// or https://
        r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+(?:[A-Z]{2,6}\.?|[A-Z0-9-]{2,}\.?)|' #domain...
        r'localhost|' #localhost...
        r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})' # ...or ip
        r'(?::\d+)?' # optional port
        r'(?:/?|[/?]\S+)$', re.IGNORECASE)
    if re.fullmatch(regex, url) is None:
        return
    inFile = open(file, 'r')
    inData = json.load(inFile)
    inFile.close()
    # outFile = open('pretty_' + file, 'w') #create temp instead
    # json.dump(inData, outFile, sort_keys=False, indent=4)
    # outFile.close()
    client = Elasticsearch(url)
    for i, e in enumerate(inData):
        client.index(index=index, id=i, document=e)


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print('Usage: pushES <file> <index> <url>')
        sys.exit(-1)
    pushES(sys.argv[1], sys.argv[2], sys.argv[3])


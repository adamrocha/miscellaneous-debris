#!/usr/bin/env python3
# Query Docker replica API
# Author: arocha 2020-09-08

import argparse
import json
import requests
import sys

parser = argparse.ArgumentParser()
parser.add_argument('-A', '--api', type = str, required = True)
parser.add_argument('-U', '--username', type = str, required = True)
parser.add_argument('-P', '--password', type = str, required = True)
args = parser.parse_args()
headers = {'Content-Type': 'application/json; charset=utf-8'}
response = requests.get(args.api, headers=headers, auth=(args.username, args.password))

def replicaStatus():
    objects = response.text.encode('utf8')
    replicaHealth = json.loads(objects)['replica_health']
    for (k, v) in replicaHealth.items():
        v = str(v)
        if v == "OK":
            print('Replicas Healthy: ' + str(replicaHealth))
            sys.exit(0)
        else:
            print('Replicas Error: ' + str(replicaHealth))
            sys.exit(2)

def main():
    replicaStatus()

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# Query Docker replica API
# Author: arocha 2020-08-26

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
objects = response.text.encode('utf8')
replicaHealth = json.loads(objects)['replica_health']

def replicaStatus():
    for (k, v) in replicaHealth.items():
        v = str(v)
        if v == "OK":
            print('HTTP: ' + str(response.status_code) + ' -- ' + 'Replicas Healthy: ' + str(replicaHealth))
            sys.exit(0)
        else:
            print('HTTP: ' + str(response.status_code) + ' -- ' + 'Replicas Error: ' + str(replicaHealth))
            sys.exit(2)

replicaStatus()

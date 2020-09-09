#!/usr/bin/env python3
# Query Docker replica API
# Author: arocha 2020-09-08

import argparse
import json
import requests

def authArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument('-A', '--api', type = str, required = True)
    parser.add_argument('-U', '--username', type = str, required = True)
    parser.add_argument('-P', '--password', type = str, required = True)
    args = parser.parse_args()
    headers = {'Content-Type': 'application/json; charset=utf-8'}
    response = requests.get(args.api, headers=headers, auth=(args.username, args.password))
    return response

try:
    def httpCode():
        response = authArgs()
        statusCode = response.status_code
        if statusCode != 200:
            print("HTTP Error: " + str(response.status_code))
            exit(2)
except Exception as e:
    print(e)

def replicaStatus():
    response = authArgs()
    objects = response.text.encode('utf8')
    replicaHealth = json.loads(objects)['replica_health']
    for (k, v) in replicaHealth.items():
        v = str(v)
        if v == "OK":
            print('Replicas Healthy: ' + str(replicaHealth))
            exit(0)
        else:
            print('Replicas Error: ' + str(replicaHealth))
            exit(2)

def main():
    httpCode()
    replicaStatus()

if __name__ == "__main__":
    main()

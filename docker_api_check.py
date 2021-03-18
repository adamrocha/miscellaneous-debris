#!/usr/bin/env python3
# Query Docker API objects
# Author: Adam Rocha 2020-09-08
# Last modified: 2021-03-17

import argparse
import json
import sys
import requests


def getArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument('-A', '--api', type=str, required=True)
    parser.add_argument('-U', '--username', type=str, required=True)
    parser.add_argument('-P', '--password', type=str, required=True)
    args = parser.parse_args()
    return args


def getObjects(args):
    try:
        headers = {'Content-Type': 'application/json; charset=utf-8'}
        response = requests.get(args.api,
                                headers=headers,
                                auth=(args.username, args.password))
        if response.status_code != 200:
            print(response.content)
            sys.exit(2)
        objects = response.content.decode('utf8')
        return objects
    except Exception as e:
        print(e)
        sys.exit(2)


def replicaStatus(objects):
    try:
        replicaHealth = json.loads(objects)['replica_health']
        replicaCount = len(replicaHealth)
        if replicaCount < 3:
            print('Replica quorum error: ' + str(replicaCount) + ' replicas exist')
            sys.exit(2)
        items = replicaHealth.items()
        for value in items:
            if value != "OK":
                print('Replicas Error: ' + str(replicaHealth))
                sys.exit(2)
    except Exception as e:
        print("Object error: " + str(e))
        sys.exit(2)


def main():
    args = getArgs()
    objects = getObjects(args)
    replicaStatus(objects)


if __name__ == "__main__":
    main()

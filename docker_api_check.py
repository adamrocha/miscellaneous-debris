#!/usr/bin/env python3
# Query Docker API objects
# Author: Adam Rocha 2020-09-08
# Last modified: 2021-03-17

import argparse
import json
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
        response = requests.get(args.api, headers=headers, auth=(args.username, args.password))
        if response.status_code != 200:
            print(response.content)
            exit(2)
        objects = response.content.decode('utf8')
        return objects
    except Exception as e:
        print(e)
        exit(2)


def replicaStatus(objects):
    try:
        replicaHealth = json.loads(objects)['replica_health']
        replicaCount = len(replicaHealth)
        if replicaCount < 3:
            print('Replica quorum error: ' + str(replicaCount) + ' replicas exist')
            exit(2)
        for v in replicaHealth.items():
            if v != "OK":
                print('Replicas Error: ' + str(replicaHealth))
                exit(2)
            else:
                print('OK - Replicas Healthy' + str(replicaHealth))
                exit(0)
    except Exception as e:
        print("Object error: " + str(e))
        exit(2)


def main():
    args = getArgs()
    objects = getObjects(args)
    replicaStatus(objects)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Query Docker API objects
Author: Adam Rocha 2020-09-08
Last modified: 2021-03-17
"""

import argparse
import json
import sys
import requests


def get_args():
    """ Gather authentication arguements """
    parser = argparse.ArgumentParser()
    parser.add_argument('-A', '--api', type=str, required=True)
    parser.add_argument('-U', '--username', type=str, required=True)
    parser.add_argument('-P', '--password', type=str, required=True)
    args = parser.parse_args()
    return args


def get_objects(args):
    """ Authenticate and collect objects """
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


def replica_status(objects):
    """ Print replica status """
    try:
        status = json.loads(objects)['replica_health']
        count = len(status)
        if count < 3:
            print('Replica quorum error: ' + str(count) + ' replicas exist')
            sys.exit(2)
        items = status.items()
        for key, value in items:
            if value != "OK":
                print('Replicas Error: ' + str(status))
                sys.exit(2)
    except Exception as e:
        print("Object error: " + str(e))
        sys.exit(2)


def main():
    """ Main funtion handling """
    args = get_args()
    objects = get_objects(args)
    replica_status(objects)


if __name__ == "__main__":
    main()

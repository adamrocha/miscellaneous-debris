#!/usr/bin/env python3
# Fetch external IP from the internet
# Author: Adam Rocha

import requests


def fetchIP():
    try:
        url = "https://ident.me"
        response = requests.get(url)
        return response.text
    except Exception as e:
        print(e)


def main():
    externalIP = fetchIP()
    print(externalIP)


if __name__ == "__main__":
    main()

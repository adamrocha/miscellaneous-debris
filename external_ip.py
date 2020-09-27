#!/usr/bin/env python3
# Fetch external IP from the internet

import requests


def fetchIP():
    url = "https://ident.me"
    response = requests.get(url)
    return response.text


def main():
    externalIP = fetchIP()
    print(externalIP)

if __name__ == "__main__":
    main()

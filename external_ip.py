#!/usr/bin/env python3
"""
Fetch external IP from the internet
Author: Adam Rocha
"""

import requests


def fetch_ip():
    """ Query IP from the internet """
    try:
        url = "https://ident.me"
        response = requests.get(url)
        return response.text
    except Exception as e:
        print(e)


def main():
    """ Main function handling """
    external_ip = fetch_ip()
    print(external_ip)


if __name__ == "__main__":
    main()

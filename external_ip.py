#!/usr/bin/env python3
# Fetch external IP from the internet

import requests

url = "https://ident.me"
response = requests.get(url)

print(response.text)

#print(urllib.request.urlopen('https://ident.me').read().decode('utf8'))

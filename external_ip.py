#!/usr/bin/env python3
# Grabs your external ip form the internet

import urllib.request
print(urllib.request.urlopen('https://ident.me').read().decode('utf8'))

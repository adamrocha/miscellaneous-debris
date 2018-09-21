#!/usr/bin/env python3
# This script will query DNS and/or rDNS in within the same script.

import socket
# import sys

target = 'localhost'  # (sys.argv[1])


def validIp():
    try:
        socket.inet_aton(target)
        return True
    except OSError:
        return False


def getIp():
    try:
        host = socket.gethostbyname(target)
        return host
    except Exception:
        pass


def getHostname():
    try:
        address = socket.gethostbyaddr(getIp())
        return address
    except Exception:
        pass

for x in target:
    if validIp() is False:
        print(' Query '.center(50, '*'))
        print(target + ' DNS resolves to: ' + str(getIp()) + '\n')
        print(str(getIp()) + ' rDNS resolves to: ' + str(getHostname()))
        print(' Done '.center(50, '*'))
        break
    if validIp() is True:
        print(' Query '.center(50, '*'))
        print(str(getIp()) + ' rDNS resolves to: ' + str(getHostname()))
        print(' Done '.center(50, '*'))
        break

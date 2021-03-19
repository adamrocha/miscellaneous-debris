#!/usr/bin/env python3
"""

Return Two way DNS
"""

import socket
import sys

target = (sys.argv[1])


def valid_ip():
    """ Validate IP is valid """
    try:
        valid = socket.inet_aton(target)
        return valid
    except OSError:
        return False


def get_ip():
    """ Get hostname """
    try:
        host = socket.gethostbyname(target)
        return host
    except Exception:
        pass


def get_hostname():
    """ Get IP """
    try:
        address = socket.gethostbyaddr(get_ip())
        return address
    except Exception:
        pass


for x in target:
    if valid_ip() is False:
        print(' Query '.center(50, '*'))
        print(target + ' DNS resolves to: ' + str(get_ip()) + '\n')
        print(str(get_ip()) + ' rDNS resolves to: ' + str(get_hostname()))
        print(' Done '.center(50, '*'))
        break
    if valid_ip() is True:
        print(' Query '.center(50, '*'))
        print(str(get_ip()) + ' rDNS resolves to: ' + str(get_hostname()))
        print(' Done '.center(50, '*'))
        break

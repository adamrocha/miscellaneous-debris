#!/usr/bin/env python3
"""
This will generate random IP's to a file
"""

import random
import socket
import struct
import time

print("how many IP's would you like to print?")
set = input()
print("Enter your file including path if required\nie: /tmp/randip.txt")
target_file = input()
for x in range(int(set)):
    f = open(target_file, "a")
    f.write(socket.inet_ntoa(struct.pack('>I', random.randint(1, 0xffffffff))))
    f.write("\n")
    time.sleep(1)

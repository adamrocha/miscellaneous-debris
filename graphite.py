#!/usr/bin/env python3
# Generate random numbers within range


import random
import subprocess
import time

while True:
    r = random.randint(1, 300)
#    t = time.time()
    t = subprocess.getoutput(['date +%s'])
    print("foo.bar " + str(r) + " " + str(t))
    time.sleep(1)

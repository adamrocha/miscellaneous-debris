#!/usr/bin/env python3
# Generate random numbers within range

import random
import time


def randInt():
    r = random.randint(1, 300)
    t = time.strftime('%c')
    return str(t) + " --> " + str(r)


def main():
    rand = randInt()
    print(rand)

if __name__ == "__main__":
    main()

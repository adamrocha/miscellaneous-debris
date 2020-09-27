#!/usr/bin/env python3
# Generate random numbers within range

import random
import time


def main():
    r = random.randint(1, 300)
    t = time.strftime('%c')
    print(str(t) + " --> " + str(r))

if __name__ == "__main__":
    main()

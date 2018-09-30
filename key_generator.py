#!/usr/bin/env python3
# Generate a random key defined by integer range

from random import choice
from random import randint
import string

characters = string.ascii_letters + string.digits + string.punctuation
password = "".join(choice(characters) for x in range(randint(24, 32)))
print(password)

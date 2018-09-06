#!/usr/bin/env python

from random import choice
from random import randint
import string

characters = string.ascii_letters + string.punctuation + string.digits
password = "".join(choice(characters) for x in range(randint(24, 32)))
print(password)

#!/usr/bin/env python

from random import choice
from random import randint
import string

characters = string.ascii_letters + string.punctuation + string.digits
password = "".join(choice(characters) for x in range(randint(16, 24)))
print(password)

#!/bin/bash

while read -r line; do
  ssh -o PasswordAuthentication=no -n "$line" hostname &>/dev/null
  if [ $? -ne 0 ]; then
    echo "$line"
  fi
done

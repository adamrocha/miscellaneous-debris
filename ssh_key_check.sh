#!/usr/bin/env bash
# Test public key auth against a list. Some options listed.
# -o PubkeyAuthentication=no
# -o PasswordAuthentication=no
# -o KbdInteractiveAuthentication=no
# -o ChallengeResponseAuthentication=no
# -o UserKnownHostsFile=/dev/null
# -o StrictHostKeyChecking=no
# -o ConnectTimeout=5

while read -r line; do
  ssh \
  -o PasswordAuthentication=no \
  -o ChallengeResponseAuthentication=no \
  -o UserKnownHostsFile=/dev/null \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  -n "$line" &>/dev/null
  if [ $? -ne 0 ]; then
    echo "$line"
  fi
done

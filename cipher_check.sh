#!/usr/bin/env bash
# Check openssl ciphers against a URL.
# OpenSSL requires the port number.

host=$1
delay=1
ciphers=$(openssl ciphers 'ALL:eNULL' | sed -e 's/:/ /g')

echo Obtaining cipher list from "$(openssl version)".
for cipher in $(printf '%s' "${ciphers[@]}")
do
  echo -n Testing "$cipher"...
  result=$(echo -n | openssl s_client -cipher "$cipher" -connect "$host" 2>&1)
  if [[ "$result" =~ ":error:" ]] ; then
    error=$(echo -n $result | cut -d':' -f6)
    echo Failed \("$error"\)
  elif [[ "$result" = "Cipher is ${cipher}" || "$result" =~ "Cipher    :" ]] ; then
    echo "Success!"
  else
    echo Unknown Response
    echo "$result"
  fi
  sleep $delay
done

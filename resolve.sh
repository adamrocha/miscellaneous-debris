#!/bin/bash
# bash two way DNS

host=$(host "$1")
ip=$(echo "$host" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')

printf "##################################\\n"
printf "DNS resolves to...\\n\\n"

if [[ "$host" =~ "not found" ]] ; then
  printf "Host not found\\n"
else
  echo "$host"
fi

printf "\\n\\nrDNS resolves to...\\n\\n"

if [[ $(host "$ip") =~ "not found" ]] ; then
  printf "Host not found\\n"
else
  host "$ip"
fi

printf "##################################\\n"

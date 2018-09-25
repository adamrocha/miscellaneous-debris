#!/bin/bash
# bash two way DNS

host=$(host "$1")
ip=$(echo "$host" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')

echo
printf "DNS resolves to...\\n\\n%s$host\\n\\n"
printf "rDNS resolves to...\\n\\n"
host "$ip"
echo

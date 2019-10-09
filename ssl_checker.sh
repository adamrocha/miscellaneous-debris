#!/usr/bin/env bash
# SSL check


printf "Enter hostname or IP:\n"
read -r HOST
printf "Enter TLS version or blank for preferred\n -tls1, -tls1_1 -tls1_2:\n"
read -r TLSV

echo | openssl s_client -connect $HOST:443 $TLSV

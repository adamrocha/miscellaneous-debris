#!/usr/bin/env bash
# Generate a random IP and write to file

echo "Enter the name of your file: "
read -r file
echo "How many IP's would you like: "
read -r num

for i in $(seq 1 "$num")
do
  echo $((RANDOM%256)).$((RANDOM%256)).$((RANDOM%256)).$((RANDOM%256)) >> "$file"
  sleep 1
done

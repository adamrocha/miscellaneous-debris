#!/bin/bash
# Get current swap usage for all running processes
# Pipe the output to "sort -rnk3" to get sorted output
# Erik Ljungstrom 27/05/2011 (kernel 2.6.16)
# Modified by Mikko Rantalainen 2012-08-09
# Modified by Marc Methot 2014-09-18
# Modified by Adam Rocha 2018-09-15

SUM=0
OVERALL=0
for DIR in $(find /proc/ -maxdepth 1 -type d -regex "^/proc/[0-9]+")
do
  PID=$(echo "$DIR" | cut -d / -f 3)
  PROGNAME=$(ps -p "$PID" -o comm --no-headers)
  for SWAP in $(grep VmSwap "$DIR"/status 2>/dev/null | awk '{ print $2 }')
  do
    (( SUM=SUM+SWAP ))
  done
  if [ "$SUM" -gt 0 ] ; then
    echo "PID=$PID swapped: $SUM KB - ($PROGNAME)"
  fi
  (( OVERALL=OVERALL+SUM ))
  SUM=0
done
echo "Overall swapped: $OVERALL KB"

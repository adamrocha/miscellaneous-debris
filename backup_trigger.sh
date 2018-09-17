#!/bin/bash

# Report failed backups over 24hrs

currentTime=$(date +%s)
backupFileCreated=$(stat -c %X $(ls -1rt /mnt/<backup_folder>/* |tail -1))
difference=$((currentTime - backupFileCreated))

if [ $difference -ge 86400 ] ; then
  curl -k -u '<user>:<pass>' -X POST -H 'Content-Type:application/json' -d '{"action":"EventsRouter", "method":"add_event", "data":[{"summary":"Error: Backups have not been done since `date -d @$backupFileCreated`. Please generate a ticket for review during business hours.", "device":"backups", "component":"", "severity":"Error", "evclasskey":"", "evclass":"/Status"}], "type":"rpc", "tid":1}' 'https://<host>/zport/dmd/evconsole_router'
fi

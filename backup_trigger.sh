#!/bin/bash
# Report failed backups over 24hrs and post to zenoss event console
# via JSON API

currentTime=$(date +%s)
backupFileCreated=$(stat -c %X "$(find /mnt/nuzenoss_backups/* -type f -exec ls -1rt {} + |tail -1)")
difference=$((currentTime - backupFileCreated))
sinceDate=$(date -d@"$backupFileCreated")

if [ $difference -ge 86400 ] ; then
  curl -k -u "<username:password>" -X POST -H "Content-Type:application/json" -d "{\"action\":\"EventsRouter\", \"method\":\"add_event\", \"data\":[{\"summary\":\"Error: Backups have not been completed since $sinceDate. Please generate a ticket for review during business hours.\", \"device\":\"Backups\", \"component\":\"\", \"severity\":\"Error\", \"evclasskey\":\"\", \"evclass\":\"/Status\"}], \"type\":\"rpc\", \"tid\":1}" "https://<url>/zport/dmd/evconsole_router"
fi

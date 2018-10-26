#!/usr/bin/env bash
# Remove old debian kernel packages

dpkg -l linux-{image,headers,modules}-* |\
awk '{print $2}' |\
grep -E '[0-9]+\.[0-9]+\.[0-9]+' |\
grep -v "$(uname -r | cut -d- -f-2)" |\
xargs apt  purge -y --dry-run
update-grub2

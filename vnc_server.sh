#!/usr/bin/env bash
# My VNC Server
/usr/local/bin/x11vnc \
  -auth /var/run/lightdm/root/:0 \
  -display :0 \
  -xkb \
  -forever \
  -shared \
  -rfbport 5900 \
&>/dev/null & disown

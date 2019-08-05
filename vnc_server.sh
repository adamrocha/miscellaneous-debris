1 #!/usr/bin/env bash
2 # My VNC Server
3
4 /usr/local/bin/x11vnc \
5  -auth /var/run/lightdm/root/:0 \
6  -display :0 \
7  -xkb \
8  -forever \
9  -shared \
10  -rfbport 5900 \
11 &>/dev/null & disown

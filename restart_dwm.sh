#!/bin/bash
# Rebuild and restart dwm

notify-send "dwm" "Rebuilding..." --urgency=low

cd /home/n0ko/bling/dwm

if ! make clean >> /tmp/dwm_build.log 2>&1; then
    notify-send "dwm" "Clean failed!" --urgency=critical
    exit 1
fi

if ! make >> /tmp/dwm_build.log 2>&1; then
    notify-send "dwm" "Build failed! Check /tmp/dwm_build.log" --urgency=critical
    exit 1
fi

if ! sudo make install >> /tmp/dwm_build.log 2>&1; then
    notify-send "dwm" "Install failed!" --urgency=critical
    exit 1
fi

notify-send "dwm" "Restarting..." --urgency=normal
sleep 0.5
killall dwm

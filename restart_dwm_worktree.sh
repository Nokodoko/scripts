#!/bin/bash
# Rebuild and restart dwm from the zellij-claude worktree

notify-send "dwm" "Rebuilding (worktree)..." --urgency=low

cd /home/n0ko/bling/dwm-zellij-claude

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

notify-send "dwm" "Restarting (worktree)..." --urgency=normal
sleep 0.5
killall dwm

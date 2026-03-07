#!/bin/bash
# dwm-hotswap-pertag.sh - Build and restart dwm pertag build
#
# Builds the pertag dwm version, installs it, and kills the running
# instance so the .xinitrc restart loop relaunches the new binary.

set -euo pipefail

LOCKFILE="/tmp/dwm-hotswap-pertag.lock"
BUILD_LOG="/tmp/dwm_build_pertag.log"
SRC_DIR="/home/n0ko/bling/dwm-pertag"

# Single-instance lock (non-blocking)
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    notify-send "dwm hotswap" "Another hotswap is already in progress" --urgency=normal
    exit 1
fi

# Verify source directory exists
if [[ ! -d "$SRC_DIR" ]]; then
    notify-send "dwm hotswap" "Source directory not found: $SRC_DIR" --urgency=critical
    exit 1
fi

notify-send "dwm" "Building pertag..." --urgency=low

cd "$SRC_DIR"

if ! make clean >> "$BUILD_LOG" 2>&1; then
    notify-send "dwm" "Clean failed for pertag!" --urgency=critical
    exit 1
fi

if ! make >> "$BUILD_LOG" 2>&1; then
    notify-send "dwm" "Build failed for pertag! Check $BUILD_LOG" --urgency=critical
    exit 1
fi

if ! sudo make install >> "$BUILD_LOG" 2>&1; then
    notify-send "dwm" "Install failed for pertag!" --urgency=critical
    exit 1
fi

notify-send "dwm" "Switching to pertag..." --urgency=normal
sleep 0.5

# Refresh wallpaper after restart (runs in background, waits for new dwm)
(sleep 2 && feh --bg-fill ~/Pictures/archCraft.png --bg-fill ~/Pictures/archCraft.png) &

# Kill dwm to trigger restart loop in .xinitrc
killall dwm

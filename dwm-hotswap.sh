#!/bin/bash
# dwm-hotswap.sh - Unified dwm build-and-restart script
# Usage: dwm-hotswap.sh [base|pertag]
#
# Builds the appropriate dwm version, installs it, and kills the running
# instance so the .xinitrc restart loop relaunches the new binary.
#
# State tracking: writes current version to /tmp/dwm-monitor-state

set -euo pipefail

LOCKFILE="/tmp/dwm-hotswap.lock"
STATE_FILE="/tmp/dwm-monitor-state"
BUILD_LOG="/tmp/dwm_build.log"
BASE_DIR="/home/n0ko/bling/dwm"
PERTAG_DIR="/home/n0ko/bling/dwm-pertag"

VERSION="${1:-base}"

# Validate argument
if [[ "$VERSION" != "base" && "$VERSION" != "pertag" ]]; then
    notify-send "dwm hotswap" "Invalid version: $VERSION (use 'base' or 'pertag')" --urgency=critical
    exit 1
fi

# Single-instance lock (non-blocking)
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    notify-send "dwm hotswap" "Another hotswap is already in progress" --urgency=normal
    exit 1
fi

# Idempotency: skip if already running the requested version
if [[ -f "$STATE_FILE" ]]; then
    CURRENT_VERSION=$(cat "$STATE_FILE" 2>/dev/null || echo "unknown")
    if [[ "$CURRENT_VERSION" == "$VERSION" ]]; then
        notify-send "dwm hotswap" "Already running $VERSION version" --urgency=low
        exit 0
    fi
fi

# Select source directory
if [[ "$VERSION" == "pertag" ]]; then
    SRC_DIR="$PERTAG_DIR"
    LABEL="pertag (quad-monitor)"
else
    SRC_DIR="$BASE_DIR"
    LABEL="base (single-monitor)"
fi

# Verify source directory exists
if [[ ! -d "$SRC_DIR" ]]; then
    notify-send "dwm hotswap" "Source directory not found: $SRC_DIR" --urgency=critical
    exit 1
fi

notify-send "dwm" "Building $LABEL..." --urgency=low

# Build
cd "$SRC_DIR"

if ! make clean >> "$BUILD_LOG" 2>&1; then
    notify-send "dwm" "Clean failed for $LABEL!" --urgency=critical
    exit 1
fi

if ! make >> "$BUILD_LOG" 2>&1; then
    notify-send "dwm" "Build failed for $LABEL! Check $BUILD_LOG" --urgency=critical
    exit 1
fi

if ! sudo make install >> "$BUILD_LOG" 2>&1; then
    notify-send "dwm" "Install failed for $LABEL!" --urgency=critical
    exit 1
fi

# Record current state
echo "$VERSION" > "$STATE_FILE"

notify-send "dwm" "Switching to $LABEL..." --urgency=normal
sleep 0.5

# Refresh wallpaper after restart (runs in background, waits for new dwm)
(sleep 2 && feh --bg-fill ~/Pictures/archCraft.png --bg-fill ~/Pictures/archCraft.png --bg-fill ~/Pictures/archCraft.png --bg-fill ~/Pictures/archCraft.png) &

# Kill dwm to trigger restart loop in .xinitrc
killall dwm

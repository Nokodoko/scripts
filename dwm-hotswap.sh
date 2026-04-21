#!/bin/bash
# dwm-hotswap.sh - Unified dwm build-and-restart script
# Usage: dwm-hotswap.sh [base|pertag|pertag-multi]
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
if [[ "$VERSION" != "base" && "$VERSION" != "pertag" && "$VERSION" != "pertag-multi" && "$VERSION" != "mobile" ]]; then
    notify-send "dwm hotswap" "Invalid version: $VERSION (use 'base', 'pertag', 'pertag-multi', or 'mobile')" --urgency=critical
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

# Select source directory and config variant
if [[ "$VERSION" == "pertag-multi" ]]; then
    SRC_DIR="$PERTAG_DIR"
    LABEL="pertag-multi (multi-monitor)"
    CONFIG_SRC="config.multi.h"
elif [[ "$VERSION" == "pertag" ]]; then
    SRC_DIR="$PERTAG_DIR"
    LABEL="pertag (single-monitor)"
    CONFIG_SRC="config.single.h"
elif [[ "$VERSION" == "mobile" ]]; then
    SRC_DIR="$PERTAG_DIR"
    LABEL="mobile (eDP-1 + DP-1 strip)"
    CONFIG_SRC="config.mobile.h"
else
    SRC_DIR="$BASE_DIR"
    LABEL="base (single-monitor)"
    CONFIG_SRC=""
fi

# Verify source directory exists
if [[ ! -d "$SRC_DIR" ]]; then
    notify-send "dwm hotswap" "Source directory not found: $SRC_DIR" --urgency=critical
    exit 1
fi

# For pertag variants, symlink the correct config before building
if [[ -n "$CONFIG_SRC" ]]; then
    if [[ ! -f "$SRC_DIR/$CONFIG_SRC" ]]; then
        notify-send "dwm hotswap" "Config variant not found: $SRC_DIR/$CONFIG_SRC" --urgency=critical
        exit 1
    fi
    ln -sf "$CONFIG_SRC" "$SRC_DIR/config.h"
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
# pertag-multi: 4 outputs (built-in + 3 externals); single-monitor modes: 1 output
if [[ "$VERSION" == "pertag-multi" ]]; then
    (sleep 2 && feh --bg-fill ~/Pictures/archCraft.png \
        --bg-fill ~/Pictures/archCraft.png \
        --bg-fill ~/Pictures/archCraft.png \
        --bg-fill ~/Pictures/archCraft.png) &
elif [[ "$VERSION" == "mobile" ]]; then
    (sleep 2 && feh --bg-fill ~/Pictures/archCraft.png \
        --bg-fill ~/Pictures/archCraft.png) &
else
    (sleep 2 && feh --bg-fill ~/Pictures/archCraft.png) &
fi

# Kill dwm to trigger restart loop in .xinitrc
killall dwm

# Unmute default sink after restart — PipeWire sometimes mutes the Ryzen
# analog output during xrandr-triggered HDMI audio device reconfiguration
(sleep 3 && pactl set-sink-mute @DEFAULT_SINK@ 0) &

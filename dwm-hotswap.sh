#!/bin/bash
# dwm-hotswap.sh - Unified dwm build-and-restart script
# Usage: dwm-hotswap.sh [base|pertag|pertag-multi|mobile]
#        dwm-hotswap.sh --verify
#
# Builds the appropriate dwm version, installs it, and kills the running
# instance so the .xinitrc restart loop relaunches the new binary.
#
# State tracking: /tmp/dwm-monitor-state is a VERIFIED cache, not a trusted
# claim. It stores version + a sha256 of the installed binary + a sorted
# fingerprint of connected xrandr outputs. The guard recomputes both and only
# skips the build if BOTH still match reality; any mismatch — or the legacy
# bare-word format — invalidates the cache and forces a real build+verify
# pass. This is what stops "no signal" from ever hiding behind "already
# running version X" again: even a legitimate skip still reapplies display
# geometry for whatever's actually plugged in right now.

set -euo pipefail

LOCKFILE="/tmp/dwm-hotswap.lock"
STATE_FILE="/tmp/dwm-monitor-state"
BUILD_LOG="/tmp/dwm_build.log"
BASE_DIR="/home/n0ko/bling/dwm"
PERTAG_DIR="/home/n0ko/bling/dwm-pertag"
DWM_BIN="/usr/local/bin/dwm"
SCRIPTS_DIR="/home/n0ko/scripts"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"

# ── Reality probes ──────────────────────────────────────────────────────────

current_binhash() {
    if [[ -f "$DWM_BIN" ]]; then
        sha256sum "$DWM_BIN" | awk '{print $1}'
    else
        echo "missing"
    fi
}

current_outputs() {
    local o
    o=$(xrandr --query 2>/dev/null | grep -E ' connected' | awk '{print $1}' | sort | paste -sd, -) || true
    printf '%s\n' "${o:-none}"
}

connected_external_count() {
    local n
    n=$(xrandr --query 2>/dev/null | grep -cE '^(DP|HDMI)-[0-9]+ connected') || true
    printf '%s\n' "${n:-0}"
}

# Populates ST_VERSION/ST_BINHASH/ST_OUTPUTS from the state file if it's in
# the current key=value format and complete. Returns 1 (globals blanked) for
# a missing file, the legacy bare-word format, or a truncated file.
read_state_file() {
    ST_VERSION="" ST_BINHASH="" ST_OUTPUTS=""
    [[ -f "$STATE_FILE" ]] || return 1
    grep -q '^version=' "$STATE_FILE" 2>/dev/null || return 1  # legacy bare-word format
    ST_VERSION=$(grep '^version=' "$STATE_FILE" 2>/dev/null | tail -1 | cut -d= -f2-) || true
    ST_BINHASH=$(grep '^binhash=' "$STATE_FILE" 2>/dev/null | tail -1 | cut -d= -f2-) || true
    ST_OUTPUTS=$(grep '^outputs=' "$STATE_FILE" 2>/dev/null | tail -1 | cut -d= -f2-) || true
    [[ -n "$ST_VERSION" && -n "$ST_BINHASH" ]]
}

write_state_file() {
    {
        echo "version=$1"
        echo "binhash=$(current_binhash)"
        echo "outputs=$(current_outputs)"
    } > "$STATE_FILE"
}

# Reapplies display geometry for whatever's connected right now, without
# touching the dwm binary. Used when the guard finds the binary already
# verified correct but the caller may not have reconfigured xrandr itself
# (e.g. a direct keybind re-triggering the same version).
apply_layout_for_reality() {
    local ext_count
    ext_count=$(connected_external_count)
    if [[ "$ext_count" -ge 2 ]]; then
        # lewis-layout.sh ends by re-invoking this script for pertag-multi.
        # That nested call hits our own flock (held for this process's
        # lifetime) and fails fast with "another hotswap in progress" — safe
        # and expected here, since the binary is already verified; only the
        # xrandr geometry lewis-layout.sh applies first is what we need.
        "$SCRIPTS_DIR/lewis-layout.sh" || true
        echo "3-monitor stacked ($(current_outputs))"
    elif [[ "$ext_count" -eq 1 ]]; then
        "$SCRIPTS_DIR/mobile-layout.sh"
        echo "eDP-1+ext stacked ($(current_outputs))"
    else
        echo "eDP-1 only ($(current_outputs))"
    fi
}

# ── --verify mode ────────────────────────────────────────────────────────────
# Recomputes reality vs the state file. Quiet + exit 0 if consistent; on any
# divergence, notify-send the specific mismatch and exit nonzero. This runs
# before the lock is taken since it's read-only.
if [[ "${1:-}" == "--verify" ]]; then
    if ! read_state_file; then
        notify-send "dwm hotswap verify" "State file missing or in legacy format — invalid" --urgency=critical
        exit 1
    fi
    REAL_BINHASH=$(current_binhash)
    REAL_OUTPUTS=$(current_outputs)
    DIVERGENCE=""
    [[ "$ST_BINHASH" == "$REAL_BINHASH" ]] || DIVERGENCE+="binhash state=$ST_BINHASH real=$REAL_BINHASH; "
    [[ "$ST_OUTPUTS" == "$REAL_OUTPUTS" ]] || DIVERGENCE+="outputs state=$ST_OUTPUTS real=$REAL_OUTPUTS; "
    if [[ -n "$DIVERGENCE" ]]; then
        notify-send "dwm hotswap verify" "State diverged from reality: $DIVERGENCE" --urgency=critical
        exit 1
    fi
    exit 0
fi

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

# Guard: skip the build only if the state file is current-format AND its
# binhash/outputs both still match reality right now. Any mismatch —
# including the legacy bare-word format — invalidates the cache.
if read_state_file && [[ "$ST_VERSION" == "$VERSION" ]] \
    && [[ "$ST_BINHASH" == "$(current_binhash)" ]] \
    && [[ "$ST_OUTPUTS" == "$(current_outputs)" ]]; then
    LAYOUT_DESC=$(apply_layout_for_reality)
    notify-send "dwm hotswap" "$VERSION binary verified (hash match); layout applied: $LAYOUT_DESC" --urgency=low
    exit 0
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

# Record verified state: fresh binhash + current outputs, now that install
# actually happened.
write_state_file "$VERSION"

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

# Self-verify: confirm the state we just wrote matches reality, and report
# VERIFIED state in the final notification — never just echo what we assumed.
if "$SELF" --verify; then
    notify-send "dwm hotswap" "$LABEL binary verified (hash match); outputs: $(current_outputs)" --urgency=normal
else
    notify-send "dwm hotswap" "Post-swap verification FAILED for $VERSION — state file inconsistent" --urgency=critical
    exit 1
fi

#!/bin/bash
# dwm-monitor-listener.sh - Monitor hotplug listener daemon
#
# Listens for DRM subsystem events via udevadm and automatically switches
# between base dwm (single monitor) and pertag dwm (dual monitor).
#
# Features:
#   - Event-driven via udevadm monitor (no polling)
#   - Debounces rapid connect/disconnect events (configurable cooldown)
#   - Idempotent: won't restart if already running correct version
#   - Single-instance enforcement via PID file
#   - Dunst notifications for all state changes
#   - State file tracking at /tmp/dwm-monitor-state
#
# Usage: dwm-monitor-listener.sh [--daemon]
#   --daemon: fork to background and write PID file

set -uo pipefail

# --- Configuration ---
DEBOUNCE_SECONDS=3
PID_FILE="/tmp/dwm-monitor-listener.pid"
STATE_FILE="/tmp/dwm-monitor-state"
HOTSWAP_SCRIPT="/home/n0ko/scripts/dwm-hotswap.sh"
LOG_FILE="/tmp/dwm-monitor-listener.log"

# --- Functions ---

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

notify() {
    local urgency="${2:-normal}"
    notify-send "dwm monitor" "$1" --urgency="$urgency" 2>/dev/null || true
}

get_monitor_count() {
    # Count connected monitors via xrandr
    # Filter out disconnected and count only "connected" outputs
    local count
    count=$(xrandr --query 2>/dev/null | grep -c ' connected ')
    echo "$count"
}

get_current_version() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

desired_version_for_count() {
    local count="$1"
    if [[ "$count" -ge 2 ]]; then
        echo "pertag-multi"
    else
        echo "pertag"
    fi
}

enforce_single_instance() {
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            log_msg "Another instance (PID $old_pid) is already running. Exiting."
            echo "Another dwm-monitor-listener is already running (PID $old_pid)."
            exit 1
        fi
        # Stale PID file, clean up
        rm -f "$PID_FILE"
    fi
    echo $$ > "$PID_FILE"
}

cleanup() {
    log_msg "Shutting down monitor listener (PID $$)"
    rm -f "$PID_FILE"
    # Kill the udevadm monitor subprocess if still running
    if [[ -n "${UDEVADM_PID:-}" ]] && kill -0 "$UDEVADM_PID" 2>/dev/null; then
        kill "$UDEVADM_PID" 2>/dev/null || true
    fi
    exit 0
}

handle_monitor_change() {
    local monitor_count
    monitor_count=$(get_monitor_count)
    local desired
    desired=$(desired_version_for_count "$monitor_count")
    local current
    current=$(get_current_version)

    log_msg "Monitor change detected: $monitor_count monitor(s), current=$current, desired=$desired"

    if [[ "$current" == "$desired" ]]; then
        log_msg "Already running $desired version. No action needed."
        return
    fi

    if [[ "$desired" == "pertag-multi" ]]; then
        notify "Multi-monitor detected ($monitor_count monitors). Switching to pertag-multi mode..." "normal"
        log_msg "Switching to pertag-multi (multi-monitor) mode"
    else
        notify "Single monitor detected. Switching to pertag (single-monitor) mode..." "normal"
        log_msg "Switching to pertag (single-monitor) mode"
    fi

    # Run the hotswap script (it handles building, installing, and restarting)
    if "$HOTSWAP_SCRIPT" "$desired" >> "$LOG_FILE" 2>&1; then
        log_msg "Hotswap to $desired completed successfully"
        if [[ "$desired" == "pertag-multi" ]]; then
            notify "Pertag-multi mode active. Multi-monitor per-tag layouts enabled." "normal"
        else
            notify "Pertag mode active. Single-monitor per-tag layouts enabled." "normal"
        fi
    else
        log_msg "ERROR: Hotswap to $desired failed!"
        notify "Hotswap to $desired FAILED! Check $LOG_FILE" "critical"
    fi
}

# --- Main ---

# Handle daemon mode
DAEMON_MODE=0
if [[ "${1:-}" == "--daemon" ]]; then
    DAEMON_MODE=1
fi

# Truncate log on fresh start
echo "--- dwm-monitor-listener started at $(date) ---" > "$LOG_FILE"

enforce_single_instance

trap cleanup EXIT INT TERM

log_msg "Monitor listener started (PID $$)"
notify "Monitor listener started" "low"

# Initial state check on startup
INITIAL_COUNT=$(get_monitor_count)
INITIAL_DESIRED=$(desired_version_for_count "$INITIAL_COUNT")
INITIAL_CURRENT=$(get_current_version)
log_msg "Initial state: $INITIAL_COUNT monitor(s), current=$INITIAL_CURRENT, desired=$INITIAL_DESIRED"

if [[ "$INITIAL_CURRENT" == "unknown" ]]; then
    # First run: set the state without hotswapping (assume running version matches)
    # Only hotswap if we can determine we need a different version
    if [[ "$INITIAL_COUNT" -ge 2 && "$INITIAL_CURRENT" != "pertag-multi" ]]; then
        handle_monitor_change
    elif [[ "$INITIAL_COUNT" -lt 2 && "$INITIAL_CURRENT" != "pertag" ]]; then
        # Write pertag state since single-monitor default is now pertag
        echo "pertag" > "$STATE_FILE"
        log_msg "Set initial state to pertag"
    fi
fi

# Debounce tracking
LAST_EVENT_TIME=0

# Start udevadm monitor for DRM subsystem events
# This is the most efficient way to detect monitor hotplug on Linux
# --subsystem-match=drm catches DisplayPort/HDMI/etc connect/disconnect
stdbuf -oL udevadm monitor --subsystem-match=drm --property 2>/dev/null | \
while IFS= read -r line; do
    # We only care about CHANGE events on card devices (not every udev line)
    if [[ "$line" == *"UDEV"*"change"*"/devices/"*"card"* ]] || \
       [[ "$line" == *"KERNEL"*"change"*"/devices/"*"card"* ]]; then

        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - LAST_EVENT_TIME))

        if [[ "$TIME_DIFF" -lt "$DEBOUNCE_SECONDS" ]]; then
            log_msg "Debounced event (${TIME_DIFF}s since last, need ${DEBOUNCE_SECONDS}s cooldown)"
            continue
        fi

        LAST_EVENT_TIME=$CURRENT_TIME
        log_msg "DRM event: $line"

        # Small delay to let the kernel finish setting up the new display
        sleep 1

        handle_monitor_change
    fi
done &

UDEVADM_PID=$!
log_msg "udevadm monitor started (PID $UDEVADM_PID)"

# Wait for the udevadm pipeline to finish (which it won't, unless killed)
wait "$UDEVADM_PID" 2>/dev/null || true

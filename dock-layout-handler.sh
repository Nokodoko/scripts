#!/bin/bash
# dock-layout-handler.sh — Called by systemd on dock connect/disconnect
# Usage: dock-layout-handler.sh connect|disconnect
#
# Deduplication: uses a lockfile so multiple udev events don't race.
# Retry: on connect, retries up to 5 times waiting for CRTCs to be ready.

set -euo pipefail

export DISPLAY=:0
export XAUTHORITY=/home/n0ko/.Xauthority
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u n0ko)/bus"

LOCKFILE="/tmp/dock-layout-handler.lock"
ACTION="${1:-}"

# Single-instance lock (non-blocking) — skip if another handler is already running
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    echo "dock-layout-handler: another instance running, skipping" >&2
    exit 0
fi

case "$ACTION" in
    connect)
        # MST hub needs time to enumerate displays and allocate CRTCs.
        # Retry with increasing delays.
        for attempt in 1 2 3 4 5; do
            sleep $((attempt * 2))  # 2, 4, 6, 8, 10 seconds
            if /home/n0ko/scripts/lewis-layout.sh 2>&1; then
                exit 0
            fi
            echo "dock-layout-handler: attempt $attempt failed, retrying..." >&2
        done
        echo "dock-layout-handler: all attempts failed" >&2
        exit 1
        ;;
    disconnect)
        sleep 1
        /home/n0ko/scripts/dwm-hotswap.sh pertag
        ;;
    *)
        echo "Usage: $0 connect|disconnect" >&2
        exit 1
        ;;
esac

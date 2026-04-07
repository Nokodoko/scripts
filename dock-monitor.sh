#!/bin/bash
# dock-monitor.sh — Event-driven dock display handler
# Listens for DRM hotplug events via udevadm monitor (blocks, no polling).
# On hotplug: debounces, frees stale CRTCs, waits for CRTC readiness, applies layout.

set -euo pipefail

export DISPLAY=:0
export XAUTHORITY=/home/n0ko/.Xauthority
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

LOCKFILE="/tmp/dock-monitor-action.lock"
DEBOUNCE_SECONDS=5
LAST_ACTION_FILE="/tmp/dock-monitor-last"

log() { echo "[dock-monitor] $(date '+%H:%M:%S') $*"; }

# ── NIC switching ──────────────────────────────────────────────────────────────
# On dock: bring up eth0 with DHCP, disable wlan0
# On undock: bring wlan0 back via iwd, drop eth0

switch_to_ethernet() {
    if ! ip link show eth0 &>/dev/null; then
        log "eth0 not present, skipping NIC switch"
        return
    fi

    log "Switching to ethernet (eth0)"
    sudo ip link set eth0 up 2>/dev/null || true
    sleep 2  # Wait for link to come up

    # The system dhcpcd daemon ignores eth0 on hotplug. Use dhcpcd -T to
    # probe for a lease, then apply it manually with ip addr/route.
    log "Probing DHCP on eth0..."
    local lease_info
    lease_info=$(sudo dhcpcd -T eth0 2>&1 | grep 'leased' || true)

    if [[ -n "$lease_info" ]]; then
        local ip
        ip=$(echo "$lease_info" | grep -oP 'leased \K[0-9.]+')
        if [[ -n "$ip" ]]; then
            log "DHCP offered $ip, applying manually"
            sudo ip addr add "$ip/24" dev eth0 2>/dev/null || true
            sudo ip route add default via 192.168.50.1 dev eth0 metric 100 2>/dev/null || true
        fi
    else
        log "DHCP probe failed, no lease"
    fi

    # Wait briefly for IP to appear
    sleep 2

    # Verify actual connectivity through eth0 before killing wlan0
    if ip addr show eth0 | grep -q 'inet ' && ping -c1 -W2 -I eth0 192.168.50.1 &>/dev/null; then
        log "eth0 verified (IP + gateway reachable), disabling wlan0"
        sudo ip link set wlan0 down
        # Restart dhcpcd so DNS resolvers update for the new interface
        log "Restarting dhcpcd for DNS"
        sudo systemctl restart dhcpcd 2>/dev/null || true
    else
        log "WARNING: eth0 not ready, keeping wlan0 active"
    fi
}

switch_to_wifi() {
    log "Switching to wifi (wlan0)"
    sudo ip link set eth0 down 2>/dev/null || true
    sudo ip addr flush dev eth0 2>/dev/null || true
    sudo ip link set wlan0 up
    # Restart dhcpcd so it picks up wlan0 and updates DNS resolvers
    log "Restarting dhcpcd for wlan0 + DNS"
    sudo systemctl restart dhcpcd 2>/dev/null || true
    # iwd should auto-reconnect to known networks
    sleep 3
    if ! ip addr show wlan0 | grep -q 'inet '; then
        log "wlan0 has no IP, requesting DHCP"
        sudo dhcpcd -b wlan0 2>/dev/null || true
    fi
    log "wlan0 active"
}

# Count connected DP outputs
count_dp() {
    xrandr --query 2>/dev/null | grep -cE '^DP-[0-9]+ connected' || echo 0
}

# Wait until xrandr can allocate CRTCs for all connected DP outputs.
# Frees stale disconnected outputs first, then tries enabling one at a time.
wait_for_crtcs() {
    local max_attempts=10
    for attempt in $(seq 1 $max_attempts); do
        # Free stale CRTCs
        while IFS= read -r stale; do
            log "Freeing stale CRTC on $stale"
            xrandr --output "$stale" --off 2>/dev/null || true
        done < <(xrandr --query 2>/dev/null | grep -E '^DP-[0-9]+ disconnected [0-9]' | awk '{print $1}')

        # Check if we can enable a DP output
        local test_dp
        test_dp=$(xrandr --query 2>/dev/null | grep -E '^DP-[0-9]+ connected' | head -1 | awk '{print $1}')
        if [[ -n "$test_dp" ]]; then
            if xrandr --output "$test_dp" --preferred --right-of eDP-1 2>/dev/null; then
                xrandr --output "$test_dp" --off 2>/dev/null || true
                log "CRTCs ready (attempt $attempt)"
                return 0
            fi
        fi
        log "CRTCs not ready, waiting (attempt $attempt/$max_attempts)..."
        sleep 2
    done
    log "CRTCs never became ready"
    return 1
}

handle_hotplug() {
    # Debounce: skip if we acted within DEBOUNCE_SECONDS
    if [[ -f "$LAST_ACTION_FILE" ]]; then
        local last now diff
        last=$(cat "$LAST_ACTION_FILE")
        now=$(date +%s)
        diff=$((now - last))
        if [[ $diff -lt $DEBOUNCE_SECONDS ]]; then
            log "Debounce: skipping (${diff}s since last action)"
            return
        fi
    fi

    # Single-instance lock for the action phase
    (
        flock -n 200 || { log "Another action in progress, skipping"; return; }

        date +%s > "$LAST_ACTION_FILE"

        sleep 3  # Let MST hub settle after hotplug event

        local dp_count
        dp_count=$(count_dp)
        log "Hotplug event: $dp_count external DP outputs detected"

        if [[ "$dp_count" -ge 2 ]]; then
            log "Dock detected, switching to 3-monitor layout"
            switch_to_ethernet
            if wait_for_crtcs; then
                /home/n0ko/scripts/lewis-layout.sh 2>&1 | while read -r line; do log "$line"; done
            else
                log "ERROR: Could not get CRTCs ready, staying on eDP-1"
            fi
        elif [[ "$dp_count" -eq 1 ]]; then
            log "Single external, switching to 2-monitor layout"
            switch_to_ethernet
            /home/n0ko/scripts/lewis-layout.sh 2>&1 | while read -r line; do log "$line"; done
        else
            log "No externals, switching to single-monitor pertag"
            switch_to_wifi
            /home/n0ko/scripts/dwm-hotswap.sh pertag 2>&1 | while read -r line; do log "$line"; done
        fi
    ) 200>"$LOCKFILE"
}

log "Starting dock monitor (event-driven, no polling)"

# Block on udevadm monitor — zero CPU when idle.
# Filter to DRM subsystem change events (hotplug).
udevadm monitor --subsystem-match=drm --udev 2>/dev/null | while read -r line; do
    if [[ "$line" == *"change"* && "$line" == *"drm"* ]]; then
        handle_hotplug &
    fi
done

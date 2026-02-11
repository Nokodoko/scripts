#!/bin/bash

# Xbox Wireless Controller auto-connect daemon
# Monitors for the controller and connects when detected

XBOX_MAC="98:7A:14:5E:E8:90"
DEVICE_NAME="Xbox Wireless Controller"
SCAN_INTERVAL=30  # Seconds between scans when controller not detected

is_connected() {
    bluetoothctl info "$XBOX_MAC" 2>/dev/null | grep -q "Connected: yes"
}

connect_controller() {
    echo "Attempting to connect to $DEVICE_NAME..."
    bluetoothctl connect "$XBOX_MAC" >/dev/null 2>&1
    sleep 2
    if is_connected; then
        echo "$DEVICE_NAME connected"
        dunstify -u low "$DEVICE_NAME Connected" 2>/dev/null
        return 0
    fi
    return 1
}

echo "Xbox controller auto-connect daemon started"
echo "MAC: $XBOX_MAC"
echo "Press Ctrl+C to stop"

# Ensure bluetooth is on
bluetoothctl power on >/dev/null 2>&1

while true; do
    if is_connected; then
        # Already connected, check again in a bit
        sleep 10
        continue
    fi

    # Scan for classic bluetooth devices (Xbox uses BR/EDR)
    # This will detect the controller when it's turned on
    while read -r line; do
        if echo "$line" | grep -q "$XBOX_MAC"; then
            echo "Controller detected!"
            connect_controller && break
        fi
    done < <(timeout "$SCAN_INTERVAL" bluetoothctl scan bredr 2>&1)

    # Also try direct connect in case it was already seen
    connect_controller 2>/dev/null
done

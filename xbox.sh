#!/bin/bash

# Xbox Wireless Controller connection script
XBOX_MAC="98:7A:14:5E:E8:90"
DEVICE_NAME="Xbox Wireless Controller"

bluetoothctl power on >/dev/null 2>&1
timeout 10 bluetoothctl connect "$XBOX_MAC" >/dev/null 2>&1

if bluetoothctl info "$XBOX_MAC" 2>/dev/null | grep -q "Connected: yes"; then
    dunstify -u low "$DEVICE_NAME Connected"
else
    dunstify -u low "$DEVICE_NAME Not Connected"
fi

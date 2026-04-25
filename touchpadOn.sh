#!/bin/bash
ids=$(touchpadId.sh)
if [ -z "$ids" ]; then
    dunstify -u critical "Touchpad not found"
    exit 1
fi
failed=0
for id in $ids; do
    xinput set-prop "$id" "Device Enabled" 1 || failed=1
done
if [ $failed -eq 0 ]; then
    dunstify -u low "Touchpad Enabled"
else
    dunstify -u critical "Touchpad Not Enabled!!"
fi

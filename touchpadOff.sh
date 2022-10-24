#!/bin/bash
xinput set-prop $(touchpadId.sh) "Device Enabled" 0 &

if [ "$?" -eq 0 ]; then
    dunstify -u low "Touchpad Disabled"
else
    dunstify -u low "Touchpad Not Disabled!!"
fi

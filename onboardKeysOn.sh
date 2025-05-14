#!/bin/bash
xinput set-prop $(onboardKeyIdOn.sh) "Device Enabled" 1 &

if [ "$?" -eq 0 ]; then
    dunstify -u low "Onboard Keyboard Enabled"
else
    dunstify -u low "Onboard Keyboard Not Enabled!!"
fi

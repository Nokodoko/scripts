#!/bin/bash
xinput set-prop $(onboardKeyId.sh) "Device Enabled" 0 &

if [ "$?" -eq 0 ]; then
    dunstify -u low "Onboard Keyboard Disabled"
else
    dunstify -u low "Onboard Keyboard Not Disabled!!"
fi

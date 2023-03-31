#!/bin/bash

ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:' 


xinput set-prop 13 "Device Enabled" 1 &

if [ "$?" -eq 0 ]; then
    dunstify -u low "Touchpad Enabled"
else
    dunstify -u low "Touchpad Not Enabled!!"
fi

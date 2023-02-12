#!/bin/bash
#
ns=notify-send
#dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
#dun='dunstify -h int:value:'

CHECH=$(xrandr | rg DP3\ connected)

$CHECK
if [ $? -eq 0 ]; then
    ~/.screenlayout/workstation.sh
    $ns "Battle Station Initiated..."
else
    ~/.screenlayout/laptop.sh
    $ns "Mobile Unit Deployed"
fi


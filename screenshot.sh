#!/usr/bin/env bash

ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:'

scrot -s -e 'xclip -selection clipboard -t image/png -i $f' &
sleep 1
ns "ScreenShot Precision"

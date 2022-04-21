#!/bin/bash

#CONSTANTS
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:' 

#GIVE SPELL NAME
SPELL=$(echo "                 " | dmenu -p "Name your spell")

#OPEN EDITOR OR EXIT WITH NOTIFICATION
if [ -z $1 ]; then
    ${ns} "Make magic"
    exec kitty -e nvim ~/scripts/${SPELL}.sh
else
    ${ns} "Nothing was Created"
    exit 1
fi

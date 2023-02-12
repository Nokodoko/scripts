#!/bin/bash
#
ns=notify-send
#dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
#dun='dunstify -h int:value:'
ROFI='rofi -theme lb -dmenu -p "Select your portal"'

NETWORK=$(fd -tf -d1 . /etc/netctl -x basename | $ROFI)

sudo netctl switch-to ${NETWORK}
if [ $? -eq 0 ]; then
    $ns "Selected ${NETWORK}"
else
    $ns -u critical "Did not connect"
fi

#!/bin/bash

#CONSTANTS
DMENU='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb black'
DFY='dunstify -u low'
#GIVE SPELL NAME
SPELL=$(echo "                 " | ${DMENU} -p "Name your spell")

#OPEN EDITOR OR EXIT WITH NOTIFICATION
if [ "$?" -eq 0 ]; then
    ${DFY} "make magic"
    exec kitty -e nvim ~/scripts/${SPELL}.sh
else
    ${DFY} "Nothing was Created"
    exit 1
fi

#!/bin/bash

#CONSTANTS
RC=$?
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:'

#VARIABLES
SPELL=$(ls ~/scripts | dmenu)


#TEST AND OPEN EDITOR WITH NEW SPELL NAME
if [ -z $1 ]; then
    ${ns} "${SPELL}"
    exec kitty -e nvim ~/scripts/${SPELL}
else
    ${ns} "Nothing changed"
    exit 1
fi

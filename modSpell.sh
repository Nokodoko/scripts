#!/bin/bash

#CONSTANTS
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb black'

#VARIABLES
SPELL=$(ls ~/scripts | ${dmenu})
#TEST AND OPEN EDITOR WITH NEW SPELL NAME
if [ "$?" -eq 0 ]; then
    ${ns} -u low "${SPELL}"
    exec kitty -e nvim ~/scripts/${SPELL}
else
    ${ns} -u low "Nothing changed"
    exit 1
fi

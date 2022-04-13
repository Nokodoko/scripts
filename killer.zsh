#!/bin/bash 

#globals
ns=notify-send
RESPONSE_CODE=$?
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf white -sb red'
dun='dunstify -u low'

#get pid
process=$(ps -u ${USER} -o pid,%mem,%cpu,comm | sed -n '1!p' | sort -b -k2 -r | awk '{print $1" "$4}' | ${dmenu} -p "Kill me" | awk '{print $1}')

#kill process
kill ${process}

#test
if [ "$?" -eq 0 ]; then
    ${dun} "Merked! ${process}"
else
    ${ns} "nothing died..."
fi

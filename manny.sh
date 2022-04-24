#!/bin/bash 

dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb black'
ns=notify-send

#SELECT MANPAGE
${ns} -u low  "KNOW:" "<i>No thief, however skillful, can rob one of knowledge, and that is why knowledge is the best and safest treasure to acquire.</i>"
#IF DESIRED, SUBSTITUTE `man -k` WITH `apropos`
SPELL=$(man -k . | awk '{print $1$2}' | dmenu -p "Tome:")

#RUN SPELL
exec kitty -e manned.sh ${SPELL}

if [ "$?" -ne 0 ]; then
    ${ns} -u low "Learning nothing I see...${RC}"
    exit 1
fi

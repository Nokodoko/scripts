#!/bin/bash 

RC=$?
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
ns=notify-send

#SELECT MANPAGE
${ns} % "<i>No thief, however skillful, can rob one of knowledge, and that is why knowledge is the best and safest treasure to acquire.</i>"
#IF DESIRED, SUBSTITUTE `man -k` WITH `apropos`
SPELL=$(man -k . | awk '{print $1$2}' | dmenu -p "Spell:")

#RUN SPELL
exec kitty -e manned.sh ${SPELL}

if [ ${RC} -eq 0 ]; then
    continue
else
    ${ns} "Learning nothing I see...${RC}"
fi

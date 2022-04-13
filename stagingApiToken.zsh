#!/bin/bash

#variables
RESPONSE_CODE=$?
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb blue'
repos=$(cat ~/capacity/repos/scripts/bin/repos | ${dmenu} -p "Staging Token")
dun='dunstify -h int:value:'


#making token
makeToken(){
    stagingToken $1 | rg -i -A 1 core | sed -n 2p | xclip -sel c
}

#User information
${dun}0 "Making..."

#call token
makeToken ${repos}

#User information 
${dun}100 "Complete"

#!/bin/bash

#variables
RESPONSE_CODE=$?
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
repos=$(cat ~/capacity/repos/scripts/bin/repos | ${dmenu} -p "Prod Token")
dun='dunstify -h int:value:'


#making token
makeToken(){
    prodApiToken $1 | rg -i -A 1 core | sed -n 2p | xclip -sel c
}

#User information
${dun}0 "Making..."

#call token
makeToken ${repos}

#User information 
${dun}100 "Complete"

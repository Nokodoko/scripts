#!/bin/bash

#VARIABES
RESPONSE_CODE=$?
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
repos=$(cat ~/capacity/repos/scripts/bin/repos | ${dmenu} -p "Staging Token")
dun='dunstify -h int:value:'


#MAKING TOKEN
makeToken(){
    stagingToken $1 | rg -i -A 1 core | sed -n 2p | xclip -sel c
}

#USER INFORMATION
${dun}0 "Making..."

#CAL TOKEN
makeToken ${repos}

#USER INFORMATION 
${dun}100 "Complete"

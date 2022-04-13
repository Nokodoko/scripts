#!/bin/bash 

#variables
RESPONSE_CODE=$?
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb blue'
dun='dunstify -h int:value:'

val=$(aws iam list-users | grep -i username | sed s/,// > ~/users.md && cat ~/users.md | awk '{print $2}' | sed s/\"//g | ${dmenu}) 
resetpassword.zsh ${val}


#testing
if [ "$?" -eq 0 ]; then
    ${dun}100 "Password Complete"
    rm ~/users.md
else
    ${ns} "Failed to Create Password, $?"
    rm ~/users.md
fi



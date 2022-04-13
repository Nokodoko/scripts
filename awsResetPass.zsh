#!/bin/bash 

#variables
RESPONSE_CODE=$?
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb blue'
dun='dunstify -h int:value:'

#make list
aws iam list-users | grep -i username | sed s/,// | sed s/\"//g | awk '{print $2}' > ~/fifo/f &

val=$(cat ~/fifo/f | ${dmenu})

#reset password
resetpassword.zsh ${val}


#testing
if [ "$?" -eq 0 ]; then
    ${dun}100 "Password Complete"
else
    ${ns} "Failed to Create Password, $?"
fi


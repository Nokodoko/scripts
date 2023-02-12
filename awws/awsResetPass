#!/bin/bash 

#VARIABLES
RESPONSE_CODE=$?
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
dun='dunstify -h int:value:'

#MAKE LIST
aws iam list-users | grep -i username | sed "s/,//;s/\"//g" | awk '{print $2}' > ~/fifo/f &

val=$(cat ~/fifo/f | ${dmenu})

#RESET PASSWORD
resetpassword.zsh ${val} 


#TESTING
if [ "$?" -eq 0 ]; then
    ${dun}100 "Password Complete"
else
    ${ns} "Failed to Create Password, $?"
fi


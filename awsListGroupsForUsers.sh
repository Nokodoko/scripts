#!/bin/bash

ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:'
userName=$(~/scripts/awsListUsers.sh)

aws iam list-groups-for-user --user-name $userName

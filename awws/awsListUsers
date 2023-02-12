#!/bin/bash

ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:'

aws iam list-users | rg -i username | awk -F : '{print $2}' |sed 's/"//g' | sed 's/,.*//g' | dmenu

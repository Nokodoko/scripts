#!/bin/bash

dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:'

aws iam list-instance-profiles | rg -i InstanceProfileName | awk -F : '{print $2}' | sed 's/,//;s/"//g' | dmenu

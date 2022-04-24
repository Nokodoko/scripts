#!/bin/bash

#-----TODO-----#
#1. function to pull / branch (with ticket) 

NS=notify-send
DMENU='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb black'
DFY='dunstify'
BASE=~/capacity/repos/dev/ 

FILE=$(fd -td -tf yaml $BASE | $DMENU -p "Pick your file") 

#TESTING
if [ "$?" -eq 0 ]; then
    $DFY "Fix This"
    exec kitty -e nvim $FILE
else
    $DFY "No Service Selected"
    exit 1
fi

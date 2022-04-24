#!/bin/bash

#FUNCTIONS
function DUNL() {
    dunstify -u low $@
}
function SEARCH() {
    $(find $1 -type f 1 -maxdepth -1)
}

#VARIABLES
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb black'

BASE=$SEARCH
#review case statements
case 
if [ -z $1 ]; then
    BASE | $(find -$1 -type f -maxdepth -1)

esac
else
fi



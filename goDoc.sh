#!/bin/bash

ns=notify-send
DMENU='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb black'
DUNL='dunstify -u low' 
DUNN='dunstify -u normal' 

#FIND THE LIBRARY
LIB=$(echo "            " | ${DMENU} -p "Find your library")

#FIND TYPE OR FUNCTION
go doc $LIB | rg func\|type | ${DMENU} -p "Find your type or function" | xargs -0 ${DUNL} 
#if [ "$?" -eq 0 ]; then
#    $LIB 
#else
#   ${DUNN} "I didn't find your library" 
#   exit 1
#fi
 

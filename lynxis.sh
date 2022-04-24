#!/bin/bash

ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb black'
dun='dunstify -h int:value:' 

SEARCH=$(echo "                                       " | dmenu -p "Enter your search")

#DEFINE BROWSER SEARCH
function brow() {
    lynx -cfg=/home/n0ko/.config/lynx/lynx.cfg https://duckduckgo.com/?ia=web&q={$SEARCH}
}

#SEARCH BROWSER
function search() {
    exec kitty -e ${brow}
}

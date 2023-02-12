#!/bin/bash
#
#ns=notify-send
#dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
#dun='dunstify -h int:value:' 

ERASE=$(dfu-programmer atmega32u4 erase --force)

# $1 = keyboard name $2 = keyboard file (c file)
function flash() {
    $ERASE
    qmk flash -kb $1 -km $2
}

#function reviung41() {
#    $ERASE
#    qmk flash -kb reviung41 -km default
#}

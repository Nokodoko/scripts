#!/bin/bash
#
NS=notify-send
DMENU='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
DUN='dunstify -h int:value:'

$NS -u low "Yo!"

gum input --prompt "Speak:  " | xargs -0 sgpt

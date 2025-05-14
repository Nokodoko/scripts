#!/usr/bin/env bash

ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:'

$ns 'Recording Terminated'
xdotool search --name "OBS 31.0.0-1 OBS 31.0.0-1 - Profile: Untitled - Scenes: Untitled" windowactivate --sync key "Ctrl+Shift+X"

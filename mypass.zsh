#!/bin/bash
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
#rofi='rofi -theme arthur -dmenu -p "Kill me"'
#rofi='rofi -theme docu -dmenu -p "Kill me"' -- might be good for databases
rofi='rofi -theme sidebar -font "VictorMono 20" -dmenu -p "myPass"'

val=$(cat ~/.pass/pass.md | rg _ | ${rofi})
cat ~/.pass/pass.md | rg -i -A 2 ${val} | sed -n 2p | xclip -sel c

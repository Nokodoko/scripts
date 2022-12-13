#!/bin/bash
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
rofi='rofi -theme DarkBlue -dmenu -p "Kill me"'

val=$(cat ~/.pass/pass.md | rg _ | ${rofi})
cat ~/.pass/pass.md | rg -i -A 2 ${val} | sed -n 2p | xclip -sel c


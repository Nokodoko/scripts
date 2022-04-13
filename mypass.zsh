#!/bin/bash
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb blue'

val=$(cat ~/.pass/pass.md | rg _ | ${dmenu})
cat ~/.pass/pass.md | rg -i -A 2 ${val} | sed -n 2p | xclip -sel c


#!/bin/bash

ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:' 

echo -e 'power on\ndefault-agent\npair 38:8F:30:F9:1B:0B\nconnect 38:8F:30:F9:1B:0B\ntrust 38:8F:30:F9:1B:0B\nagent off\nquit' | bluetoothctl

if [ "$?" -eq 0 ]; then
    dunstify -u low 'Galaxy Buds Pro 2 Connected'
else
    dunstify -u low 'Galaxy Buds Pro 2 Not Connected'
fi

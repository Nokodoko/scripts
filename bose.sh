#!/bin/bash

ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:' 

echo -e 'power on\ndefault-agent\npair C8:7B:23:C5:9B:01\nconnect C8:7B:23:C5:9B:01\ntrust C8:7B:23:C5:9B:01\nagent off\nquit' | bluetoothctl

if [ "$?" -eq 0 ]; then
    dunstify -u low 'Bose QC Connected'
else
    dunstify -u low 'Bose QC Not Connected'
fi

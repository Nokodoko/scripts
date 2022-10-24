#!/bin/bash
DFYL='dunstify -u low'

echo -e 'power on\npair 64:33:DB:AD:EF:A3\nconnect 64:33:DB:AD:EF:A3\ntrust 64:33:DB:AD:EF:A3\nagent off\nquit' | bluetoothctl
if [ "$?" -eq 0 ]; then
    $DFYL "Anne Connected"
else
    $DFYL "Anne NOT Connected"
fi

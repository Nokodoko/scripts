#!/bin/bash
DFYL='dunstctl -u low'

echo -e 'disconnect 30:50:75:B5:8F:FB\ntrust 30:50:75:B5:8F:FB\nagent off\nquit' | bluetoothctl
if [ "$?" -eq 0 ]; then
    $DFYL "Disconnected!"
else
    $DFYL "Still Connected"
fi

#!/bin/bash

BATTERYLEVEL=$(acpi | sed -n 1p | sed 's/%//' | awk -F , '{print $2}')

if [ $BATTERYLEVEL -lt 10 ]; then
    dunstify -u critical 'LOW BATTERY!'
fi

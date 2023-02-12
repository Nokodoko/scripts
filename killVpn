#!/bin/bash 

SESSION=$(openvpn3 sessions-list | rg -i -B5 connected | rg -i path | awk '{print $2}')
openvpn3 session-manage --path ${SESSION} --disconnect >& /dev/null

if [ "$?" -eq 0 ]; then
    dunstify -u low "vpn session teminated"
else
    dunstify -u normal "still connected!"
fi

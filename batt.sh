#!/bin/bash 

bat=$(cat /sys/class/power_supply/BAT0/capacity)
ns=notify-send -u critical

while [ ${bat} < 15 ]
do 
    ${ns} "I'm Dying!"
done
    

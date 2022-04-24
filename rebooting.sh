#!/bin/bash 

#variables
ns=notify-send 

#shutting down the computer
${ns} "Brb!"
echo "kmonad ~/.config/kmonad/config.kbd &" >> ~/.zshenv 
sleep .5
reboot

#testing if it's still alive
if [ "$?" -ne 0 ]; then
    ${ns} -u low "I'm still here!"
fi

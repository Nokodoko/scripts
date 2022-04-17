#!/bin/bash 

#variables
RC=$?
ns=notify-send 

#shutting down the computer
${ns} "Brb!"
echo "kmonad ~/.config/kmonad/config.kbd &" >> ~/.zshenv 
sleep .5
reboot

#testing if it's still alive
if [ ${RC} -eq 0 ]; then
    continue
else
    ${ns} "I'm still here!"
fi

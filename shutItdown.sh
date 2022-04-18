#!/bin/bash 

#variables
RC=$?
ns=notify-send 

#shutting down the computer
${ns} "Later!"
echo "kmonad ~/.config/kmonad/config.kbd &" >> ~/.zshenv 
sleep .5
shutdown -h now

#testing if it's still alive
if [ ${RC} -eq 0 ]; then
    continue
else
    ${ns} "I'm still here!"
fi

#!/bin/bash 

#VARIABLES
RC=$?
ns=notify-send 

#SHUTTING DOWN THE COMPUTER
${ns} "Later!"
echo "kmonad ~/.config/kmonad/config.kbd &" >> ~/.zshenv 
sleep .5
shutdown -h now

#TESTING IF IT'S STILL ALIVE
if [ ${RC} -eq 0 ]; then
    continue
else
    ${ns} "I'm still here!"
fi

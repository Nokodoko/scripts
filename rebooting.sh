#!/bin/bash

#variables
ns=notify-send

#shutting down the computer
${ns} "Brb!"
#echo "kmonad ~/.config/kmonad/config.kbd &" >> ~/.zshenv
echo "sudo kmonad ~/.config/kmonad/nuphy.kbd &" >>~/.zshenv
dunstctl close-all
sudo reboot

#testing if it's still alive
if [ "$?" -ne 0 ]; then
	${ns} -u low "I'm still here!"
fi

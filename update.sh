#!/bin/bash

ns=notify-send

if sudo pacman -Syu --noconfirm; then
    $ns 'Updated System Packages' 
else
    $ns 'Failed to Update System Packages,\n check update manually'
fi

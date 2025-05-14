#!/bin/bash

dclose.sh
sudo ~/scripts/brightUp.py
cat /sys/class/backlight/intel_backlight/brightness | xargs -0 notify-send -u low 'Brightness Increased:'

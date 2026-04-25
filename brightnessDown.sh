#!/bin/bash

dclose.sh
sudo ~/scripts/brightDown.py
cat /sys/class/backlight/amdgpu_bl1/brightness | xargs -0 notify-send -u low 'Brightness Decreased:'

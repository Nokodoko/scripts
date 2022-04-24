#!/bin/bash 

xrandr --output eDP-1 --primary --mode 3456x2160 --pos 2160x1328 --rotate normal --output DP-1 --off --output DP-2 --mode 3840x2160 --pos 0x0 --rotate right --output DP-3 --mode 1917x1080 --pos 5616x1028 --rotate normal && refresh.sh
refresh.sh

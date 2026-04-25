#!/bin/bash

# Get screen dimensions via xrandr
SCREEN=$(xrandr | grep -w connected | head -1 | grep -oP '\d+x\d+\+\d+\+\d+' | head -1)
SW=$(echo $SCREEN | cut -d'x' -f1)
SH=$(echo $SCREEN | cut -d'x' -f2 | cut -d'+' -f1)

# Popup dimensions (small, just for 2 options + confirm)
PW=280
PH=120

# Bottom-right with margin
X=$((SW - PW - 30))
Y=$((SH - PH - 50))

# kitty does not support `--position` the same way wezterm did; use dwm floating rule
# on WM_CLASS "gpu-select" to place the window, or use kitty's
# `--override initial_window_width/height` if size is all that matters.
exec kitty --class gpu-select -- /home/n0ko/scripts/gpu-toggle.sh

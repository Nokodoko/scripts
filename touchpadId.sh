#!/bin/bash
# Returns xinput device IDs for the built-in touchpad/trackpad and sibling mouse.
# ASUS laptops expose touchpad as Mouse + Touchpad; both must be toggled.

# Find a touchpad/trackpad device (any state: pointer, floating, etc.)
# Exclude lines that are keyboard-type devices ("slave  keyboard" in brackets)
line=$(xinput list | grep -iE 'touchpad|trackpad' | grep -v 'slave  keyboard' | head -1)
[ -z "$line" ] && exit 1

# Extract device name prefix (strip trailing Touchpad/Trackpad/Mouse)
name=$(echo "$line" | sed 's/.*[↳∼]\s*//' | sed 's/\s*id=.*//')
prefix=$(echo "$name" | sed 's/\s*\(Touchpad\|Trackpad\|Mouse\)\s*$//')

if [ -n "$prefix" ] && [ "$prefix" != "$name" ]; then
    # Find all non-keyboard devices sharing this prefix
    xinput list | grep -F "$prefix" | grep -v 'slave  keyboard' | grep -oP 'id=\K\d+'
else
    echo "$line" | grep -oP 'id=\K\d+'
fi

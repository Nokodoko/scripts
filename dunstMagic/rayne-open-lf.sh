#!/bin/bash
# Rayne notification action script
# Opens lf file manager in a floating wezterm window (dwm)
#
# Called by dunst with args: appname summary body icon urgency

APPNAME="$1"
SUMMARY="$2"
BODY="$3"
ICON="$4"
URGENCY="$5"

# Log the notification for debugging
echo "$(date): Rayne notification received - $SUMMARY: $BODY" >> /tmp/rayne-notifications.log

# Open file manager in a floating wezterm window (class wezterm-lf triggers dwm floating rule)
/home/n0ko/scripts/fm-launcher.sh lf /home/n0ko/Portfolio/rayne &

exit 0

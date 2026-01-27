#!/bin/bash

PRIME_ENV="__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia"

ACTION=$(gum choose --height 5 --cursor.foreground "#00FF00" \
    "Launch app with NVIDIA" \
    "Check current GPU" \
    "Copy PRIME prefix")

[ -z "$ACTION" ] && exit 0

case "$ACTION" in
    "Launch app with NVIDIA")
        APP=$(gum input --placeholder "Enter command to run with NVIDIA...")
        [ -z "$APP" ] && exit 0
        notify-send "GPU" "Launching with NVIDIA: $APP"
        exec env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia $APP
        ;;
    "Check current GPU")
        RENDERER=$(glxinfo | grep "OpenGL renderer")
        notify-send "GPU Info" "$RENDERER"
        gum style --foreground "#00FF00" "$RENDERER"
        sleep 2
        ;;
    "Copy PRIME prefix")
        echo -n "$PRIME_ENV " | xclip -selection clipboard
        notify-send "GPU" "PRIME prefix copied to clipboard"
        ;;
esac

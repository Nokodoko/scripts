#!/bin/bash
# File manager launcher for dwm
# Usage: fm-launcher.sh [yazi|lf] [path]
#   $1 - file manager to launch: 'yazi' or 'lf' (default: lf)
#   $2 - optional starting directory

FM="${1:-lf}"
DIR="${2:-.}"

case "$FM" in
    yazi|lf)
        exec kitty --class kitty-lf -- "$FM" "$DIR"
        ;;
    *)
        echo "Unknown file manager: $FM (supported: yazi, lf)" >&2
        exit 1
        ;;
esac

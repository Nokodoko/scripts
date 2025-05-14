#!/bin/bash

ns=notify-send
$ns "Wallpaper"

pushd ~/Pictures
feh --bg-scale $(sxiv -t -o $(fd -d1 . ~/Pictures -e jpg -e png))

#!/bin/bash

dunstify -u normal "Notifications Paused"
sleep 1
dunstctl set-paused true

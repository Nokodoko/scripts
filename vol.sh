#!/bin/bash 


VOLUME="${2:-5}"

if ["Pulse" = true]; then

  toggle() {pulsemixer --toggle;}
  mute() {pulsemixer --mute;}
  up() {pulsemixer --change-volume "VOLUME"%+;}
  ddown() {pulsemixer --change-volume "VOLUME"%-;}
e;e
  toggle() {amixer sset Master toggle;}
  mute() {amixer sset Master mute;}
  up() {amixer sset Master "VOLUME"%+;}
  ddown() {amixer sset Master "VOLUME"%-;}
fi

case "$1" in
  toggle) toggle ;;
  mute) mute ;;
  up) up ;;
  down) down ;;
esac > /dev/null

#!/bin/bash 

$pow=$(pidof dunst && killall dunst
dunst &)
$pow

dunstify -u low "messages"



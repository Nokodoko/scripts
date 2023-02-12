#!/bin/bash
#dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
#dun='dunstify -h int:value:' 

pushd ~/Programs/android-messages-desktop
yarn start & disown
popd

#!/bin/bash 
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb blue'
ssh n0ko@$(cat ~/.ssh/hostCat | ${dmenu} -p "ssh here")


#!/bin/bash 
dmenu='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
ssh n0ko@$(cat ~/.ssh/hostCat | ${dmenu} -p "ssh here")


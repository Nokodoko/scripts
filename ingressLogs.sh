#!/bin/bash

dun='dunstify -h int:value:'
tm='terminal-notifier'

kubectl logs -n nginx-ingress $(kubectl get pods -n nginx-ingress -l release=capacity-external | fzf | awk '{print $1}') 
   if [ "$?" -eq 0 ]; then
       ${dun} "SELCTED!"
#       ${tm} "SELCTED!"
   else
       dunstify -u critical "No Pod Selected"
       #${tm} "No Pod Selected"
       exit 1
   fi

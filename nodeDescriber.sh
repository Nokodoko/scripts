#!/bin/bash

LIST=$(cat ~/helmInfo/nodeTypeList.md |fzf)

kubectl get node --selector type=${LIST} -o wide | fzf | awk '{print $1}'
   if [ "$?" -eq 0 ]; then
       ${dun} "SELCTED!"
   else
       dunstify -u critical "No Node Selected"
       exit 1
   fi


#!/bin/bash 

#PARSING JUMP FILE
cat .config/lynx/jumpsUnix.html|rg href|awk -F \> '{print $2}' | awk -F \< '{print $1}'


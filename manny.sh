#!/bin/bash
ns=notify-send

#SELECT MANPAGE
#${ns} -u low  "KNOW:" "<i>No thief, however skillful, can rob one of knowledge, and that is why knowledge is the best and safest treasure to acquire.</i>"

#IF DESIRED, SUBSTITUTE `man -k` WITH `apropos`
SPELL=$(command man -k . | awk '{print $1$2}' | fzf --reverse --border --border-label='Man Pages' --prompt "Tome:")

#command man ${SPELL} | nvim -R -c 'set ft=man nomod nolist'

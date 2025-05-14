#!/bin/bash

ns=notify-send

fd -tf -d1 | fzf --layout reverse --preview 'bat --style=numbers --color=always --line-range :500 {}'




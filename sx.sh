#!/bin/bash

sed -i "s/kmonad.*//" ~/.zshenv
kill kmonad
startx

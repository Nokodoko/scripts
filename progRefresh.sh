#!/bin/bash

ns=notify-send

pushd ~/Programs
fd . -td -d1 --threads=4 -x git --git-dir={}/.git\
    --work-tree=$(pwd)/{}\
    pull --verbose
popd

ns "Updated!"

#!/bin/bash

aws ecr describe-repositories | rg -i name | awk -F : '{print $2}' | sed 's/"//g;s/,//g' | dmenu

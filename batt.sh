#!/bin/bash 

loop () {
    while true; do
      "$@"
      sleep 2
    done
}

loop /home/n0ko/programming/lua_projects/batt.lua

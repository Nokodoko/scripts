#!/bin/bash 
loop () {
    while true; do
      "$@"
      sleep 1
    done
}

loop /home/n0ko/programming/lua_projects/caps.lua

#!/bin/bash 

function manned() {
	/usr/bin/man $* | col -b | nvim -R -c 'set ft=man nomod nolist' -
}

manned $@

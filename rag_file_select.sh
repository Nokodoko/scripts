#!/bin/bash
#this is a prototype for local rag, in a shell script. Rewrite in lua and then in another system language later
#
ns=notify-send
dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:'

RAG_DIR='/home/n0ko/rag_files/'

function rag_file_selector() {
	$ns "Select your wisdom"
	fd -tf --full-path . $RAG_DIR | flist "Select Context File"
}

rag_file_selector

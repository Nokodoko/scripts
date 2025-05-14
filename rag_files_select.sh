#!/bin/bash
#this is a prototype for local rag, in a shell script. Rewrite in lua and then in another system language later
#
ns=notify-send

RAG_DIR='/home/n0ko/rag_files/'

function rag_files_selector() {
	$ns "Select your wisdom"
	fd -tf . --full-path $RAG_DIR | flist "Select Context Files"
	# use multi-select fzf function
}

#CONTEXT=$(echo $(command cat $(rag_files_selector)))
cat $(rag_files_selector)

#As a datadog sme, use the preceding document (a change request form) to create a lesson plan, as well as a guide to implement apm on a jboss server.

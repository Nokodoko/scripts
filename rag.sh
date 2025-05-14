#!/bin/bash
ns=notify-send

#FLAGS
while getopts ':m' OPTION; do
	case "$OPTION" in
	m)
		$ns "SAGE"

		#CONTEXT=$(rag_files_select.sh)
		CONTEXT=rag_files_select.sh
		read -rp "Prompt: " PROMPT
		#OUTPUT=$PROMPT >>$CONTEXT
		#$OUTPUT | xargs -o sgpt
		function COMBINE() {
			echo $1$2
		}
		$COMBINE $PROMPT $CONTEXT
		exit 0
		;;
	*)
		exit 0
		;;
	esac
done

##BASE PROGRAM
#RAG_DIR='/home/n0ko/rag_files/'
#
#function rag_file_selector() {
#	$ns "Select your wisdom"
#	fd -tf --full-path . $RAG_DIR | flist "Select Context File"
#}
#
#CONTEXT=echo $(bat -p $(rag_file_selector))
#CONTEXT | xargs -0 sgpt {}

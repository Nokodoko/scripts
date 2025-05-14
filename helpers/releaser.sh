#!/bin/bash

# HOME=/home/n0ko/
# FULLSTACK="${HOME}sbevision/sbe/sbe-full-stack"
# DMZSTACK="${HOME}sbevision/afterburners/sbe-dmz-stack"
# ADAPTERSTACK="${HOME}sbevision/adapters/sbe-adapter-stack"
# ORCHESTRATOR_DIR="${HOME}sbevision/devops/argocd-gitops/argocd-orchestrator"
#
runner() {
	job_selector() {
		glab ci list | grep "RELEASE JOB SELECTOR" | awk '{print $3}' | cut -c 2-
	}

	pushd $1

	git checkout master
	git pull

	glab release create $NAME --ref $BRANCH
}

#COLORS
function capColor() {
	TEXT=$1
	gum style --foreground "#118DFF" "$TEXT"
}

function redColor() {
	TEXT=$1
	gum style --foreground "#D82C20" "$TEXT"
}

gum style \
	--border double \
	--padding "1" \
	"SBE RELEASE"

#FLAGS
while getopts ':qmQ' OPTION; do
	case "$OPTION" in
	q)
		echo "Choose $(redColor "permission") level $(capColor "for query")"
		TYPE=$(gum choose "fullstack" "adapters" "dmzstack")
		DATABASE=$(gum filter <~/scripts/sqlQuery/dbList.md)
		~/scripts/sqlQuery/$TYPE/$DATABASE
		exit 0
		;;
	m)
		~/scripts/sqlLog/main/main.sh
		exit 0
		;;
	Q)
		~/scripts/sqlQuery/main/main.sh
		exit 0
		;;
	*)
		echo "Invalid flag"
		exit 1
		;;
	esac
done

#BASE PROGRAM
echo "Pick $(capColor "Release Train")"
TYPE=$(gum choose "fullstack" "adapters" "dmzstack")
# DATABASE=$(gum filter <~/scripts/sqlLog/dbList.md)
#
# ~/scripts/sqlLog/$TYPE/$DATABASE

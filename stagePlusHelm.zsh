#!/bin/bash

#variables
RC=$?
NS=notify-send
DMENU='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb blue'
SERVICE=$(cat ~/capacity/repos/scripts/bin/repos | ${DMENU} -p "Staging Token for")
DIR=$(echo "${SERVICE}" | sed "s/staging.*//")
FILE=$(find ~/capacity/repo/dev -type f | rg -i secrets | ${DMENU} -p "Locate File")
TIX=$(echo " " | ${DMENU} -p "Enter FULL ticket Number")
DUN='dunstify -h int:value:'

#making token and allowing for k8s to exec into pod and make token
MAKETOKEN=$(stagingToken $1 | rg -i -A 1 core | sed -n 2p)
sleep 1

#User information
${DUN}0 "Making..."

#call token
MAKETOKEN ${SERVICE}

#User information 
${DUN}100 "Token Created"

#navigate to branch 
cd ${DIR}

#git checkout ticket name
git checkout -b ${TIX}

#edit secrets file
helm secrets dec
sleep 1
sed -i "s/ey.*/${MAKETOKEN}/" ${FILE}
helm secrets enc
sleep 1

#testing secrets modification
if [ ${RC} -eq 0 ]; then
    continue 
else
    ${NS} "did not update secrets.yaml file for ${SERVICE}"
    exit 1
fi

#git boilerplate to commit and push
git commit -am "Updated ${TIX} Staging API tokens"
git push --set-upstream origin ${TIX}

#testing git push
if [ ${RC} -eq 0 ]; then
    ${DUN}100 "Pushed to gitlab!"
else
    ${NS} "Did not push the secrets file to gitlab for ${SERVICE}."
    exit 1
fi

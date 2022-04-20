#!/bin/bash
#-----README-----#
#You will have need to ensure the following environment variable is set in your shell:
# export GIT_DISCOVERY_ACROSS_FILESYSTEM=1

#VARIABLES
RC=$?

#NOTIFIERS / BLUE SELECTOR IS FOR STAGING
NS=notify-send
DMENU='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb blue'
DUN='dunstify -h int:value:'

#DIRECTORIES AND FILES
BASE=~/capacity/repos/dev/
SERVICE=$(find ${BASE} -type f | rg "secrets.yaml" | xargs dirname  | awk -F / '{print $9}' | uniq | ${DMENU} -p  "Select staging token:")

#BRANCH TO MODIFY
DIR=$(find ${BASE} -type d|rg helm|rg ${SERVICE}|sed -n 1p|awk -F / '{print $1"/"$2"/"$3"/"$4"/"$5"/"$6"/"$7"/"$8"/"$9}')
cd ${DIR}

#ENTER TICKET NUMBER"
TIX=$(echo "           " | ${DMENU} -p "Enter FULL ticket Number")

##GIT CHECKOUT TICKET NAME
git checkout master ${DIR}
git pull ${DIR}
git checkout -b ${TIX}

#TESTING GIT CHECKOUT
if [ ${RC} -eq 0 ]; then
    ${NS} "Successful Checkout"
else
    ${NS} -u critical "I didn't reach the targeted destination!! ${RC}"
    exit 1
fi

#SELECT FILE
FILE=${DIR}/helm/${SERVICE}/secrets.staging.yaml

##MAKING TOKEN AND ALLOWING FOR K8S TO EXEC INTO POD AND MAKE TOKEN
function MAKETOKEN() {
    stagingToken $1 | rg -i -A 1 core | sed -n 2p
}

#CALL TOKEN
MAKETOKEN ${SERVICE}
sleep 3

#USER NOTIFICATIONS
${DUN}0 "Making..."

##TESTING
if [ ${RC} -eq 0 ]; then
    ${DUN}100 "Token Created"
else
    ${NS} -u critical "I didn't reach the targeted destination!! ${RC}"
    exit 1
fi

#EDIT SECRETS FILE //THERE ARE TESTS BETWEEN EACH STEP

#DECRYPTING FILE
helm secrets dec ${FILE}
##TESTING
if [ ${RC} -eq 0 ]; then
    ${DUN}50 "File Decrypted"
    sleep 2
else
    ${NS} -u critical "I didn't decrypt the file ${RC}"
    exit 1
fi

#REMOVE OLD TOKEN AND REPLACE WITH NEW TOKEN
sed -i "s/TOKEN:.*/${MAKETOKEN}/" ${FILE}

##TESTING
if [ ${RC} -eq 0 ]; then
    ${DUN}50 "Updated token in ${FILE}"
else
    ${NS} -u critical "I didn't correctly upgrade the ${FILE} ${RC}"
    exit 1
fi

#RE-ENCRYPT FILE
helm secrets enc ${FILE}
##TESTING
if [[ ${RC} -eq 0 ]]; then
    ${DUN}50 "Successfully Re-encrypted ${FILE}"
else
    ${NS} -u critical "I didn't reach the targeted destination!! ${RC}"
    exit 1
fi
sleep 2

#GIT BOILERPLATE TO COMMIT AND PUSH
#COMMIT THE FILES
git commit -am "Updated ${TIX} Staging API tokens"

#TESTING
if [ ${RC} -eq 0 ]; then
    ${DUN}75 "Commited branch ${TIX}"
else
    ${NS} -u critical "I didn not successfully commit to branch ${TIX} ${RC}"
    exit 1
fi

#PUSH THE FILES && OPEN URL IN GOOGLE-CHROME
git push --set-upstream origin ${TIX} | rg https | xargs google-chrome

#TESTING GIT PUSH
if [ ${RC} -eq 0 ]; then
    ${DUN}100 "Pushed to gitlab!"
    exit 0
else
    ${NS} "Did not push the secrets file to gitlab for ${SERVICE}."
    exit 1
fi

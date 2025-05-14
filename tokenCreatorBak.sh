#!/bin/bash
#-----README-----#
#You will have need to ensure the following environment variable is set in your shell:
# export GIT_DISCOVERY_ACROSS_FILESYSTEM=1

#VARIABLES
#NOTIFIERS / BLUE SELECTOR IS FOR STAGING
NS=notify-send
#DMENU='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
DMENU='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
DUN='dunstify -h int:value:'

#DIRECTORIES AND FILES
BASE=/home/n0ko/capacity/repos/dev
SERVICE=$(fd --full-path -td -d2 ${BASE} | awk -F / '{print $3}' | sort | ${DMENU} -p  "Select staging token:")

#BRANCH TO MODIFY
DIR=$(fd --full-path -td -d3 ${BASE} | rg ${SERVICE})
cd ${DIR}

#ENTER TICKET NUMBER"
TIX=$(echo "           " | ${DMENU} -p "Enter FULL ticket Number")

##GIT CHECKOUT TICKET NAME
git checkout master ${DIR}
git pull ${DIR}
git checkout -b ${TIX}

#TESTING GIT CHECKOUT
if [ '$?' -eq 0 ]; then
    ${NS} "Successful Checkout"
else
    ${NS} -u critical "I didn't reach the targeted destination!! '$?'"
    exit 1
fi

#SELECT FILE
FILE=${BASE}${DIR}/helm/${SERVICE}/secrets.staging.yaml

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
if [ '$?' -eq 0 ]; then
    ${DUN}100 "Token Created"
else
    ${NS} -u critical "I didn't reach the targeted destination!! '$?'"
    exit 1
fi

#EDIT SECRETS FILE //THERE ARE TESTS BETWEEN EACH STEP

#DECRYPTING FILE
helm secrets dec ${FILE}
##TESTING
if [ '$?' -eq 0 ]; then
    ${DUN}50 "File Decrypted"
    sleep 2
else
    ${NS} -u critical "I didn't decrypt the file '$?'"
    exit 1
fi

#REMOVE OLD TOKEN AND REPLACE WITH NEW TOKEN
sed -i "s/TOKEN:.*/${MAKETOKEN}/" ${FILE}

##TESTING
if [ '$?' -eq 0 ]; then
    ${DUN}50 "Updated token in ${FILE}"
else
    ${NS} -u critical "I didn't correctly upgrade the ${FILE} '$?'"
    exit 1
fi

#RE-ENCRYPT FILE
helm secrets enc ${FILE}
##TESTING
if [[ '$?' -eq 0 ]]; then
    ${DUN}50 "Successfully Re-encrypted ${FILE}"
else
    ${NS} -u critical "I didn't reach the targeted destination!! '$?'"
    exit 1
fi
sleep 2

#GIT BOILERPLATE TO COMMIT AND PUSH
#COMMIT THE FILES
git commit -am "Updated ${TIX} Staging API tokens"

#TESTING
if [ '$?' -eq 0 ]; then
    ${DUN}75 "Commited branch ${TIX}"
else
    ${NS} -u critical "I didn not successfully commit to branch ${TIX} '$?'"
    exit 1
fi

#PUSH THE FILES && OPEN URL IN GOOGLE-CHROME
git push --set-upstream origin ${TIX} | rg https | xargs google-chrome

#TESTING GIT PUSH
if [ '$?' -eq 0 ]; then
    ${DUN}100 "Pushed to gitlab!"
    exit 0
else
    ${NS} "Did not push the secrets file to gitlab for ${SERVICE}."
    exit 1
fi

#!/BIN/BASH

#VARIABLES
RC=$?

#NOTIFIERS
NS=notify-send
DMENU='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb blue'
DUN='dunstify -h int:value:'

#DIRECTORIES AND FILES
BASE=~/capacity/repos/dev/
SERVICE=$(find ${BASE} -type f | rg "secrets.yaml" | xargs dirname  | awk -F / '{print $9}' | uniq | ${DMENU} -p  "Select staging token:")
DIR=$(find ${BASE} -type d | rg helm | rg ${SERVICE} | sed -n 1p)/${SERVICE}
FILE=$(find ~/capacity/repo/dev -type f | rg -i secrets | ${DMENU} -p "Locate File")
TIX=$(echo " " | ${DMENU} -p "Enter FULL ticket Number")

#MAKING TOKEN AND ALLOWING FOR K8S TO EXEC INTO POD AND MAKE TOKEN
MAKETOKEN=$(stagingToken $1 | rg -i -A 1 core | sed -n 2p)
sleep 1

#USER INFORMATION
${DUN}0 "Making..."

#CALL TOKEN
MAKETOKEN ${SERVICE}

#USER INFORMATION 
${DUN}100 "Token Created"

#NAVIGATE TO BRANCH 
cd ${DIR}

#GIT CHECKOUT TICKET NAME
git checkout -b ${TIX}

#EDIT SECRETS FILE
helm secrets dec
sleep 1
sed -i "s/ey.*/${MAKETOKEN}/" ${FILE}
helm secrets enc
sleep 1

#TESTING SECRETS MODIFICATION
if [ ${RC} -eq 0 ]; then
    continue 
else
    ${NS} "did not update secrets.yaml file for ${SERVICE}"
    exit 1
fi

#GIT BOILERPLATE TO COMMIT AND PUSH
git commit -am "Updated ${TIX} Staging API tokens"
git push --set-upstream origin ${TIX}

#TESTING GIT PUSH
if [ ${RC} -eq 0 ]; then
    ${DUN}100 "Pushed to gitlab!"
else
    ${NS} "Did not push the secrets file to gitlab for ${SERVICE}."
    exit 1
fi

#!/bin/bash
# vim:fileencoding=utf-8:ft=bash:foldmethod=marker

#-----README-----#
#You will have need to ensure the following environment variable is set in your shell:
# export GIT_DISCOVERY_ACROSS_FILESYSTEM=1

#VARIABLES
#NOTIFIERS / BLUE SELECTOR IS FOR STAGING
NS=notify-send
DMENU='dmenu -m 0 -fn VictorMono:size=17 -nf cyan -nb black -nf cyan -sb blue'
DUN='dunstify -h int:value:'
            #TESTING FOR EXISTING SECRETFILE
            if [ -z ~/secretFile]; then
                rm ~/secretFile
                dunstify -u low "removed secretFile...CLEAN UP UP AFTER YOURSELF!"
            fi

#DIRECTORIES AND FILES
BASE=~/capacity/repos/dev/
SERVICE=$(find ${BASE} -type f | rg "secrets.yaml" | xargs dirname  | awk -F / '{print $9}' | uniq | ${DMENU} -p  "Select staging token:")
   if [ "$?" -eq 0 ]; then
       continue
   else
       dunstify -u critical "Nothing Selected"
       exit 1
   fi
#BRANCH TO MODIFY
DIR=$(find ${BASE} -type d|rg helm|rg ${SERVICE}|sed -n 1p|awk -F / '{print $1"/"$2"/"$3"/"$4"/"$5"/"$6"/"$7"/"$8"/"$9}')
cd ${DIR}

        #ENTER TICKET NUMBER"
        TIX=$(echo "           " | ${DMENU} -p "Enter FULL ticket Number")
        
   if [ "$?" -eq 0 ]; then
       continue
   else
       dunstify -u critical "No ticket number"
       exit 2
   fi

##GIT CHECKOUT TICKET NAME
git pull 
git checkout master ${DIR}
git checkout -b ${TIX}
   #TESTING GIT CHECKOUT
   if [ "$?" -eq 0 ]; then
       ${NS} "Successful Checkout"
   else
       ${NS} -u critical "I didn't reach the targeted destination!! "$?""
       exit 3
   fi


#SELECT FILE
FILE=${DIR}/helm/${SERVICE}/secrets.staging.yaml
                ##MAKING TOKEN AND ALLOWING FOR K8S TO EXEC INTO POD AND MAKE TOKEN
                function MAKETOKEN() {
                    if [ -z ~/secretFile ]; then
                    stagingToken $1 | sed -n 2p > ~/secretFile
                    $DFYL "Made secretFile"
                    else
                    rm ~/secretFile 
                    $DFYL "Clean up after yourself! Removed ~/secretFile"
                    stagingToken $1 | sed -n 2p > ~/secretFile
                    fi
                }


#CALL TOKEN AND MAKETOKEN
DFYL='dunstify -u low'
DFYN='dunstify -u normal'
${DFYL} "Making..."
MAKETOKEN ${SERVICE}
    #USER NOTIFICATIONS
    if [ "$?" -eq 0 ]; then
        ${DFYL} ${TOKEN}
        ${NS} -u low "Token Created"
    else
        ${DFYL} "Exit"
        ${NS} -u low "Failed to write secretFile,\"$?\"" 
        exit 4
    fi
    
#EDIT SECRETS FILE //THERE ARE TESTS BETWEEN EACH STEP
#DECRYPTING FILE
    helm secrets dec ${FILE}
   ##TESTING
   if [ "$?" -eq 0 ]; then
       ${DFYL} "File Decrypted"
       sleep 2
   else
       ${NS} -u critical "I didn't decrypt the file "$?""
       exit 5
   fi

   sleep 2

#REMOVE OLD TOKEN AND REPLACE WITH NEW TOKEN
    sed -i "s/CORE_API_TOKEN:.*/CORE_API_TOKEN:\ \\$(cat ~/secretFile)/" ${FILE}.dec
    ##TESTING
    if [ "$?" -eq 0 ]; then
        ${DFYN} "Updated token in ${FILE}.dec"
    else
        ${NS} -u critical "I didn't correctly upgrade the ${FILE}.dec "$?""
        exit 6
    fi
    
#REMOVe old secrets.Staging.yaml file and rename $FILE
rm ${FILE} && mv ${FILE}.dec ${FILE}

#RE-ENCRYPT FILE
    helm secrets enc ${FILE}.dec
    ##TESTING
    if [ "$?" -eq 0 ]; then
        ${DFYL} "Successfully Re-encrypted ${FILE}.dec"
    else
        ${NS} -u critical "I did not RE-ENCRYPT ${FILE}.dec "$?""
        exit 7
    fi

    sleep 2

#GIT BOILERPLATE TO COMMIT AND PUSH
#COMMIT THE FILES
git add ${FILE}
git commit -m "Updated ${TIX} Staging API tokens"

    #TESTING
    if [ "$?" -eq 0 ]; then
        ${DUN}75 "Commited branch ${TIX}"
    else
        ${NS} -u critical "I did NOT successfully commit branch ${TIX} "$?""
        exit 8
    fi

#PUSH THE FILES && OPEN URL IN GOOGLE-CHROME
git push --set-upstream origin ${TIX} | rg https | xargs google-chrome
    #TESTING GIT PUSH
    if [ "$?" -eq 0 ]; then
        ${DFYL} "Pushed to gitlab!"
        rm ~/secretFile
        ${DFYN} "secretFile removed"
        exit 0
    else
        ${NS} "Did not push the secrets file to gitlab for ${SERVICE}."
        ${DFYN} "secretFile removed"
        exit 9
    fi

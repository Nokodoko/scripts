#!/bin/bash

#user-input
name=$1
dun='dunstify -h int:value:'

#make new aws password
function resetpass() {
    ~/scripts/genPass > newpass.txt; 
    aws iam update-login-profile --user-name ${name} --password $(cat newpass.txt) --no-password-reset-required;
    cat newpass.txt | xclip -sel c
    rm newpass.txt
    ${dun}50 "Making Password"
}

if [ "$?" -eq 0 ]; then
   ${dun}100 "AWS Password Generated" 
else
    dunstify -u critical "Failed to pass the new pw to aws api, $?"

fi

resetpass ${name}

#!/bin/bash 

dunstify -h int:value:0 "Beginning updates..." 
ansible-playbook ~/playbooks/update.yml
RETURN_CODE=$?

if [[ ${RETURN_CODE} -eq 0 ]]; then
    dunstify -h int:value:100 "Update Successful"
else
    notify-send "Update Failed, ${RETURN_CODE}"
fi

#!/bin/bash 

#GLOBALS
RESPONSE_CODE=$?
ns=notify-send

dig ixfr google.com

if [ ${RESPONSE_CODE} -eq 0 ]; then
    ${ns} 'well done'
else
    ${ns} 'there might be something misconfigured on your router'
fi

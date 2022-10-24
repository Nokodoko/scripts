#!/bin/bash

dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
dun='dunstify -h int:value:' 
FDQN=$(echo "                "|${dmenu} -p "Enter the requested-domain name")
#tm='terminal-notifier' 

#CHECK FOR FILE --test not working
if [[ -z ~/certs.json ]]; then
    rm ~/certs.json
    dunstify -u low "removed certs.json...CLEAN UP UP AFTER YOURSELF!"
    #${tm} "removed certs.json...CLEAN UP UP AFTER YOURSELF!"
fi

#CHECK FOR FILE --test not working
if [[ -z ~/certificate.json ]]; then
    rm ~/certificate.json
    dunstify -u low "removed certs.json...CLEAN UP UP AFTER YOURSELF!"
    #${tm} "removed certs.json...CLEAN UP UP AFTER YOURSELF!"
fi

#GENERATE LIST OF CERTIFICATES
aws acm describe-certificate --certificate-arn arn:aws:acm:us-east-1:632808888887:certificate/\
$(kubectl get svc -n articles articles-external-nginx-ingress-controller -o json | \
jq -r '.metadata.annotations."service.beta.kubernetes.io/aws-load-balancer-ssl-cert"' | \
awk -F/ '{print $2}')> ~/certs.json
    dunstify -u low "Created certs.json"
    #${tm} "Created certs.json"

#GET CNAME AND CNAME VALUES && CHECK ON THE FILE 
rg Name\|Value ~/certs.json | awk -F : '{print $2}' > ~/certificate.json

#REMOVE ALL MISCELLANEOUS TEST
sed -i '1,2d;s/[A-Z]//g;s/"//g;s/,//g' ~/certificate.json
rg com\|org ~/certificate.json > ~/certs.json

cat ~/certs.json

#CNAME VALUES
CNAMEV=$(rg validation certificate.json)

##CNAME NAMES -- so many writes :(
rg com\|org ~/certificate.json > ~/cname.json 
rg _ ~/cname.json > ~/cnamed.json
rm cname.json

CNAME=$(cat ~/cnamed.json)

aws acm request-certificate\
    --domain-name ${FDQN}\
    --subject-alternative-names ${CNAME}\
    --domain-validation-options ${CNAMEV}

rm ~/cn*
rm ~/cert*

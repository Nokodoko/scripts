#!/bin/bash

#TODO
#1.HATE THAT I HAVE TO USE 3 FILES (MANY SEPARATE OS WRITE FUNCTIONS) -- non-priority
#2. Unmarshall package in go mekes this easier

dmenu='dmenu -m 0 -fn VictorMono:size=20 -nf green -nb black -nf green -sb black'
ch='choose'
dun='dunstify -h int:value:' 
FDQN=$(echo "                "|${dmenu} -p "Enter the requested-domain name")
CNAME=$(cat ~/cnames.json)
CNAMEV=$(rg -i value ~/certs2.json| awk -F : '{print $2}')
#FDQN=$(echo "                "|${dmenu} -P "Enter the requested-domain name")
#tm='terminal-notifier' 

#VARIALBES
FILE='~/certs.json'

#CHECK FOR FILE --test not working
if [ -z ~/certs.json ]; then
    rm ~/certs.json
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
rg Name\|Value ~/certs.json > ~/certs2.json
rg com\|org ~/certs2.json| awk -F : '{print $2}' > ~/cname.json

##REMOVE ALL MISCELLANEOUS TEST
sed -i 's/"//g;s/,//g' ~/cname.json 
sed -i '1,2d' ~/cname.json 

#CNAME NAMES
rg _ ~/cname.json > ~/cnames.json && cat ~/cnames.json
#rm ~/cname.json && cat ~/cnames.json

#CNAME VALUES


##rg -i name\|value\|_ certs.json > certs2.json && ${dun} ~/certs2.json
##rg -i name\|value\|_ certs.json > certs2.json && cat ~/certs2.json
#
##PARSE CNAME AND CNAME VALUES
#awk -F : '{print $2}' certs2.json > certs.json && rm ~/certs2.json
#    dunstify -u low "Deleted ~/certs2.json"
#    #${tm} "Deleted ~/certs2.json"
#
#
##SEND CNAMEVALUES TO A SEPARATE FILE
#rg _ ~/certs.json > ~/cnameVal.json
#
#aws acm request-certificate\
#    --domain-name ${FDQN}\
#    --subject-alternative-names ${CNAME}\
#    --domain-validation-options DNS
#
##REMOVE TOP LINE OF FILE (DUPLICATE)
##clip arn
##ARN='gp -B2 '\*.capacity.com' certs.json | sed -n 2p | awk -F \" '{print $4}' > ~/arn.md'

##HELPERS##
#1. cname name script
#2. cname values script

#!/bin/bash
function flist() {
    ARG="$@"
    fzf --reverse --border --border-label="$ARG"
}

aws ec2 describe-instance | jq -c '{Name: .Reservations[] | .Instances[] | .Tags[] | .Value, ip: .Reservation[] | .Instances[] | .PrivateIpaddress}' | sed 's/,/ /;s/"//g;s/{//;s/}//' | flist "EC2 Instances"

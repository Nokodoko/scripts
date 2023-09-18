#!/bin/bash
set -x

function SERVICE(){
    kubectl get events -o json | jq '.items[] | .involvedObject.name' | sort | uniq | fzf --reverse > ~/scripts/kubed/serve.txt
}
SERVICE

#!/bin/bash
set -x

#TYPE=$(kge -o json | jq '.items[] | .involvedObject.kind' | sort | uniq | fzf --reverse)

~/scripts/kubed/kgeService.sh
SERVICE=$(cat ~/scripts/kubed/serve.txt)

function event(){
  kubectl get events | jq '.items[] | select(.involvedObject.name=='\$1') | {time: .firstTimestamp},{message: .message},{type: .involvedObject.kind}'}
}

echo $SERVICE | event

rm ~/scripts/kubed/serve.txt

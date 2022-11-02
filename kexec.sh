#!/bin/bash

#VARIABLE
PODNAME=$(kubectl get po -A | awk '{print $1, $2, $4}' | fzf | awk '{print $1, $2}')
CONTAINER=$(kubectl get po -n ${PODNAME} -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' | fzf)

#COMMAND
function exec() {
    kubectl exec -it -n ${PODNAME} -c ${CONTAINER} sh 
}

exec 

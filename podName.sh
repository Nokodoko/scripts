#!/bin/bash

function podName() {
    kubectl get po -A | awk '{print $1, $2, $4}' | fzf | awk '{print $1, $2}'
}

podName

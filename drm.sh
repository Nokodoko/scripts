#!/bin/bash

CID=$(docker images | fzf | awk '{print $3}')

docker rmi -f ${CID}

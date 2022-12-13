#!/bin/bash

CID=$(docker ps | fzf | awk '{print $1}')

docker exec -it ${CID} /bin/sh

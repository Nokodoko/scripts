#!/bin/bash

IMAGE=$(docker images | fzf | awk '{print $3}')

docker run --rm ${IMAGE}

#!/bin/bash

IMAGE=$(docker images | fzf | awk '{print $3}')

docker run -dit --entrypoint "/bin/sh" ${IMAGE} 

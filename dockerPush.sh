#!/bin/bash

for dir in */; do
    cd "$dir"
    docker build .
	cd ..
done

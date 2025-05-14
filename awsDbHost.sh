#!/bin/bash

awsDescribeDbInstance | jq '{Host: .DBInstances[]|.Endpoint.Address, Port: .DBInstances[]|.Endpoint.Port}' 
if [ $? -ne 0 ]; then
    echo 'command failed'
fi

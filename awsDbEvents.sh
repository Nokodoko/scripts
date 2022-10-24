#!/bin/bash

aws rds describe-events $(~/scripts/awsDescribeDbInstance.sh)

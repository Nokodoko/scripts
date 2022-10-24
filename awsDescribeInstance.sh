#!/bin/bash

aws rds describe-db-instances $(~/scripts/awsListDbInstanceIdentifiers.sh) | jq

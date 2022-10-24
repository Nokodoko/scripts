#!/bin/bash

aws rds describe-db-instances --db-instance-identifier $(~/scripts/awsListDbInstanceIdentifiers.sh)|jq

#!/bin/bash

aws rds describe-db-instances | rg DBInstanceIdentifier | sed 's/\"Read.*//;s/"//g;s/,//g;' | awk -F : '{print $2}' | dmenu 

#completion:
#  Remove white spaces, forget the sed command for it.

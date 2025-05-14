#!/bin/bash
#xinput | rg -i touch | tail -n 1 | awk '{print $8}' | awk -F = '{print $2}'

xinput | rg -i touch | tail -n 1 | awk '{print $5}' | awk -F = '{print $2}'

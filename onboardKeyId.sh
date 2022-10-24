#!/bin/bash
xinput | rg -i onboard | sed -n 1p | awk '{print $3}' | awk -F = '{print $2}'

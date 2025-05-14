#!/bin/bash
xinput | rg -i onboard | sed -n 2p | awk '{print $3}' | awk -F = '{print $2}'

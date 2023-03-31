#!/bin/bash
xinput | rg -i touch | sed -n 1p | awk '{print $6}' | awk -F = '{print $2}'

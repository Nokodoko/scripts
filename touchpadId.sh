#!/bin/bash
xinput | rg -i touch | awk '{print $6}' | awk -F = '{print $2}'

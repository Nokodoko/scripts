#!/bin/bash
xinput | gp -i touch | awk '{print $6}' | awk -F = '{print $2}'

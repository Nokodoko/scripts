#!/usr/bin/env zsh
# Wait for new window and switch to tag 5 (stm)
# Usage: wait_for_game.zsh <initial_window_count>

INITIAL_COUNT=$1
export DISPLAY=:0

for i in {1..600}; do
    sleep 0.5
    CURRENT_COUNT=$(xdotool search --name "" 2>/dev/null | wc -l)
    if [[ $CURRENT_COUNT -gt $INITIAL_COUNT ]]; then
        # New window detected - switch to tag 5 (stm)
        xdotool key super+5
        exit 0
    fi
done

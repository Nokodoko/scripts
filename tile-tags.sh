#!/bin/bash
# tile-tags.sh — multi-select DWM tags to view simultaneously (tile)
#
# Displays a rofi multi-select prompt listing all DWM tags.
# Tags with windows are marked with a dot indicator.
# Select 2+ tags (Shift+Enter to toggle, Enter to confirm).
# The script then combines those tags into a single view using
# xdotool to simulate DWM's view + toggleview keypresses.
#
# Dependencies: rofi, xdotool, xprop
# Trigger: <leader> t (via sxhkd or DWM keybinding)

set -euo pipefail

# --- DWM tag definitions (must match config.h) ---
TAGS=("www" "tms" "slk" ">_" "stm" "SP" "SP2" "OLR" "AI" "STM" "SSH")

# Tag indices that map to XK_1..XK_5 (DWM only binds keys for first 5 regular tags)
# Tags 0-4 map to keys 1-5
# Tags 5+ (scratchpads) are handled via special bindings and excluded from tiling
MAX_TILEABLE=5

# --- Detect occupied tags ---
# DWM doesn't expose per-window tag assignments via EWMH,
# so we map window WM_CLASS to tags using the rules from config.h.
# Windows not matching any rule get the current tagset (unknown).
declare -A CLASS_TO_TAG=(
    ["St"]=3
    ["kitty"]=3
    ["wireshark"]=-1
    ["Slack"]=2
    ["teams-for-linux"]=1
    ["mpv"]=-1
    ["firefox"]=0
    ["Vivaldi-stable"]=0
    ["chromium"]=0
    ["qutebrowser"]=0
    ["Google-chrome"]=0
    ["Electron"]=2
    ["discord"]=2
    ["steam"]=4
)

occupied=()
for ((i = 0; i < MAX_TILEABLE; i++)); do
    occupied[$i]=0
done

# Get all client windows
client_list=$(xprop -root _NET_CLIENT_LIST 2>/dev/null | sed 's/.*# //' | tr ',' ' ')

if [[ -n "$client_list" ]]; then
    for wid in $client_list; do
        # Get WM_CLASS (class name is the second field)
        wm_class=$(xprop -id "$wid" WM_CLASS 2>/dev/null | sed 's/.*", "//;s/".*//')
        if [[ -n "$wm_class" && -n "${CLASS_TO_TAG[$wm_class]+_}" ]]; then
            tag_idx=${CLASS_TO_TAG[$wm_class]}
            if ((tag_idx < MAX_TILEABLE)); then
                occupied[$tag_idx]=1
            fi
        else
            # Windows without matching rules: check if they're scratchpads
            wm_instance=$(xprop -id "$wid" WM_CLASS 2>/dev/null | sed 's/.*= "//;s/".*//')
            case "$wm_instance" in
                *-scratchpad) continue ;;  # skip scratchpads
            esac
            # Non-rule, non-scratchpad windows are on whatever tag DWM assigned.
            # We can't determine the exact tag, so we won't mark any tag as occupied for these.
            # They'll still be available for selection.
        fi
    done
fi

# --- Build rofi menu ---
menu=""
for ((i = 0; i < MAX_TILEABLE; i++)); do
    tag_name="${TAGS[$i]}"
    if ((occupied[i])); then
        indicator="●"
    else
        indicator="○"
    fi
    menu+="$((i + 1)): $indicator $tag_name\n"
done

# --- Show rofi multi-select ---
selected=$(printf "$menu" | rofi -dmenu \
    -multi-select \
    -p "Tile Tags (Shift+Enter to select, Enter to confirm)" \
    -mesg "Select 2+ tags to tile together" \
    -i \
    -theme-str 'window {width: 400px;}' \
    2>/dev/null) || exit 0

# --- Validate: need at least 2 tags ---
count=$(echo "$selected" | wc -l)
if ((count < 2)); then
    notify-send "Tile Tags" "Need at least 2 tags to tile" --urgency=low
    exit 1
fi

# --- Extract tag numbers ---
tag_nums=()
while IFS= read -r line; do
    num=$(echo "$line" | grep -oP '^\d+')
    if [[ -n "$num" ]]; then
        tag_nums+=("$num")
    fi
done <<< "$selected"

if ((${#tag_nums[@]} < 2)); then
    notify-send "Tile Tags" "Need at least 2 tags to tile" --urgency=low
    exit 1
fi

# --- Tile: view first tag, then toggleview the rest ---
# DWM keybindings:
#   Mod4 + N        = view tag N          (switch to single tag)
#   Mod4 + Ctrl + N = toggleview tag N    (add/remove tag from view)
#
# Strategy: view the first selected tag, then toggleview each additional tag

first="${tag_nums[0]}"
rest=("${tag_nums[@]:1}")

# View the first tag (Mod4 + number key)
xdotool key "super+${first}"

# Small delay to let DWM process the view change
sleep 0.05

# Toggleview each remaining tag (Mod4 + Ctrl + number key)
for num in "${rest[@]}"; do
    xdotool key "super+ctrl+${num}"
    sleep 0.02
done

notify-send "Tile Tags" "Tiled tags: ${tag_nums[*]}" --urgency=low --expire-time=2000

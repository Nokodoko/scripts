#!/usr/bin/env bash
# lister.sh — unified "lister of listers" launcher for dwm.
#
# Entry point behavior:
#   - If invoked with no args (the dwm keybinding path) we relaunch ourselves
#     inside a wezterm window using the "wezterm-lister" class so dwm's Rule
#     can float + center + size us.
#   - Inside the wezterm child we set INSIDE=1 and run the gum picker.
#
# Each picker runs in its own color scheme by exporting GUM_CHOOSE_* vars
# before invoking gum. Colors per spec:
#   run     -> green   (#00FF00)
#   killer  -> red     (#FF3030)
#   pass    -> magenta (#FF00FF)
#   wifi    -> yellow  (#FFD700)
#   blue    -> cyan    (delegated to existing blue_connect script)

set -u

WEZTERM_CLASS="wezterm-lister"

# --- outer launch ------------------------------------------------------------
if [ "${INSIDE:-0}" != "1" ]; then
    export INSIDE=1
    exec wezterm start --class "$WEZTERM_CLASS" -- "$0" "$@"
fi

# --- inner (runs inside the wezterm-lister window) ---------------------------

# Reset any inherited gum theming before each picker configures its own.
unset_gum() {
    unset GUM_CHOOSE_CURSOR_FOREGROUND GUM_CHOOSE_CURSOR_BACKGROUND \
          GUM_CHOOSE_SELECTED_FOREGROUND GUM_CHOOSE_HEADER_FOREGROUND \
          GUM_CHOOSE_ITEM_FOREGROUND GUM_CHOOSE_CURSOR \
          GUM_FILTER_INDICATOR_FOREGROUND GUM_FILTER_MATCH_FOREGROUND \
          GUM_FILTER_PROMPT_FOREGROUND GUM_FILTER_TEXT_FOREGROUND
}

apply_scheme() {
    # $1 = hex color (e.g. "#00FF00")
    local c="$1"
    export GUM_CHOOSE_CURSOR_FOREGROUND="#000000"
    export GUM_CHOOSE_CURSOR_BACKGROUND="$c"
    export GUM_CHOOSE_SELECTED_FOREGROUND="$c"
    export GUM_CHOOSE_HEADER_FOREGROUND="$c"
    export GUM_CHOOSE_ITEM_FOREGROUND="#F8F8F2"
    export GUM_CHOOSE_CURSOR="> "
    export GUM_FILTER_INDICATOR_FOREGROUND="$c"
    export GUM_FILTER_MATCH_FOREGROUND="$c"
    export GUM_FILTER_PROMPT_FOREGROUND="$c"
    export GUM_FILTER_TEXT_FOREGROUND="#F8F8F2"
}

notify() { notify-send "$@" 2>/dev/null || true; }

# --- individual listers ------------------------------------------------------

run_dmenu() {
    apply_scheme "#00FF00"
    # Collect executables on PATH (dmenu_path-style).
    local pick
    pick=$(IFS=:; for d in $PATH; do
        [ -d "$d" ] || continue
        find "$d" -maxdepth 1 -type f -executable -printf '%f\n' 2>/dev/null
    done | sort -u | gum filter --placeholder="run...") || return 0
    [ -n "$pick" ] || return 0
    setsid -f "$pick" >/dev/null 2>&1 &
}

run_killer() {
    apply_scheme "#FF3030"
    local pick pid
    # pid + command, user-owned processes only.
    pick=$(ps -u "$USER" -o pid=,comm= --sort=-pcpu \
        | awk '{printf "%6s  %s\n", $1, $2}' \
        | gum filter --placeholder="kill...") || return 0
    [ -n "$pick" ] || return 0
    pid=$(awk '{print $1}' <<<"$pick")
    [ -n "$pid" ] || return 0
    kill -9 "$pid" 2>/dev/null \
        && notify "killer" "kill -9 $pick" \
        || notify -u critical "killer" "failed to kill $pid"
}

run_pass() {
    apply_scheme "#FF00FF"
    local file="${PASS:-}"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        notify -u critical "pass" "PASS env var not set or file missing"
        return 1
    fi
    # Parse pass.md: entries are lines ending with "\_"; password is the
    # next non-empty line after the entry marker.
    local entries pick password
    entries=$(grep -E '\\_$' "$file" | sed -E 's/\\_$//')
    [ -n "$entries" ] || { notify -u critical "pass" "no entries"; return 1; }
    pick=$(printf '%s\n' "$entries" | gum filter --placeholder="pass...") || return 0
    [ -n "$pick" ] || return 0
    # Locate the entry then grab the following non-empty line.
    password=$(awk -v key="${pick}\\\\_" '
        $0 == key { found=1; next }
        found && NF { print; exit }
    ' "$file")
    if [ -z "$password" ]; then
        notify -u critical "pass" "no password found for $pick"
        return 1
    fi
    printf '%s' "$password" | xclip -selection clipboard -i
    notify "pass" "copied ${pick}; clears in 45s"
    (sleep 45 && printf '' | xclip -selection clipboard -i) >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

run_wifi() {
    apply_scheme "#FFD700"
    local pick
    [ -d /etc/netctl ] || { notify -u critical "wifi" "/etc/netctl missing"; return 1; }
    pick=$(find /etc/netctl -maxdepth 1 -type f -printf '%f\n' 2>/dev/null \
        | sort -u | gum filter --placeholder="wifi...") || return 0
    [ -n "$pick" ] || return 0
    if sudo -n netctl switch-to "$pick" 2>/dev/null; then
        notify "wifi" "connected: $pick"
    else
        # Fall back to a terminal-visible sudo prompt.
        sudo netctl switch-to "$pick" \
            && notify "wifi" "connected: $pick" \
            || notify -u critical "wifi" "failed: $pick"
    fi
}

run_blue() {
    # blue_connect already exports its own cyan/Monokai gum theme.
    apply_scheme "#00FFFF"
    if command -v blue_connect >/dev/null 2>&1; then
        blue_connect
    else
        notify -u critical "blue" "blue_connect not in PATH"
    fi
}

# --- top-level picker --------------------------------------------------------

unset_gum

# tv (television) — fuzzy-find over the list of listers. Ad-hoc channel sourced
# from a printf of the lister names.
choice=$(tv \
    --source-command "printf '%s\n' run killer pass wifi blue" \
    --input-header "lister" \
    --no-sort) || exit 0
[ -n "$choice" ] || exit 0

unset_gum
case "$choice" in
    run)    run_dmenu ;;
    killer) run_killer ;;
    pass)   run_pass ;;
    wifi)   run_wifi ;;
    blue)   run_blue ;;
    *)      exit 0 ;;
esac

#!/usr/bin/env bash
# lister.sh — unified "lister of listers" launcher for dwm.
#
# Entry point behavior:
#   - If invoked with no args (the dwm keybinding path) we relaunch ourselves
#     inside a kitty window using the "kitty-lister" class so dwm's Rule
#     can float + center + size us.
#   - Inside the kitty child we set INSIDE=1 and run the gum picker.
#
# Each picker runs in its own color scheme by exporting GUM_CHOOSE_* vars
# before invoking gum. Colors per spec:
#   run     -> green   (#00FF00)
#   killer  -> red     (#FF3030)
#   pass    -> magenta (#FF00FF)
#   wifi    -> yellow  (#FFD700)
#   blue    -> cyan    (delegated to existing blue_connect script)

set -u

KITTY_CLASS="kitty-lister"

# --- outer launch ------------------------------------------------------------
if [ "${INSIDE:-0}" != "1" ]; then
    export INSIDE=1
    exec kitty --class "$KITTY_CLASS" -- "$0" "$@"
fi

# --- inner (runs inside the kitty-lister window) ---------------------------

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

# dbase-style title box + "Choose" subtitle, colored per lister.
# $1 = title text, $2 = hex color, $3 = subtitle noun (e.g. "command"),
# $4 = optional icon glyph.
lister_header() {
    local title="$1" color="$2" noun="$3" icon="${4:-}"
    local display="$title"
    [ -n "$icon" ] && display="$icon  $title"
    gum style --border double --padding "1" --foreground "$color" --italic "$display"
    echo "Choose $(gum style --foreground "$color" --italic "$noun")"
    echo "Choose:"
    echo
}

# ANSI helpers: column 1 rendered italic + truecolor; column 2 white.
# Hex -> R;G;B for 24-bit ANSI fg escape.
hex_to_rgb() {
    local h="${1#\#}"
    printf '%d;%d;%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# $1=hex  $2=icon+name (col1)  $3=metadata (col2)
# Emits an ANSI-styled row. Column 1: italic + colored. Column 2: white.
fmt_row() {
    local rgb
    rgb=$(hex_to_rgb "$1")
    if [ -n "${3:-}" ]; then
        printf '\033[3;38;2;%sm%s\033[0m  \033[0;37m%s\033[0m\n' "$rgb" "$2" "$3"
    else
        printf '\033[3;38;2;%sm%s\033[0m\n' "$rgb" "$2"
    fi
}

# Back sentinel prepended to every filter list; if picked, signals return.
# Styled italic + dim white so it matches the column-1 aesthetic.
BACK_LABEL=$'\033[3;2;37m← Back\033[0m'
BACK_PLAIN="← Back"

notify() { notify-send "$@" 2>/dev/null || true; }

# --- individual listers ------------------------------------------------------

run_dmenu() {
    # tv fuzzy picker over PATH executables. No pagination.
    local src pick name
    # NOTE: tv detects $SHELL and spawns source-commands under it. Under zsh,
    # `for d in $PATH` does NOT split on ':' (no sh_word_split by default),
    # so the loop iterates once over the whole PATH string and yields nothing.
    # Force bash to restore POSIX word-splitting semantics.
    src=$'bash -c \'{ printf "%s\\n" "\xe2\x86\x90 Back"; IFS=:; for d in $PATH; do [ -d "$d" ] || continue; find "$d" -maxdepth 1 -executable \\! -type d -printf "%f\\n" 2>/dev/null; done | sort -u; }\''
    pick=$(tv --source-command "$src" --input-header "Run Commands" --no-sort --no-preview) || return 0
    [ -n "$pick" ] || return 0
    name=$(printf '%s' "$pick" | sed -E 's/\x1b\[[0-9;]*m//g')
    case "$name" in *"$BACK_PLAIN"*|"← Back") return 0 ;; esac
    name=${name%% *}
    [ -n "$name" ] || return 0
    setsid -f "$name" >/dev/null 2>&1 </dev/null
    sleep 0.15
    exit 0
}

run_killer() {
    # tv fuzzy picker over user-owned processes.
    # Format: "<pid>  <comm>" — first column is pid for extraction.
    local src pick plain pid
    src='{ printf "%s\n" "← Back"; ps -u "'"$USER"'" -o pid=,comm= --sort=-pcpu | awk "{printf \"%-7s %s\n\",\$1,\$2}"; }'
    pick=$(tv --source-command "$src" --input-header "Kill Processes" --no-sort --no-preview) || return 0
    [ -n "$pick" ] || return 0
    plain=$(printf '%s' "$pick" | sed -E 's/\x1b\[[0-9;]*m//g')
    case "$plain" in *"$BACK_PLAIN"*|"← Back") return 0 ;; esac
    pid=$(printf '%s' "$plain" | awk '{print $1}')
    [[ "$pid" =~ ^[0-9]+$ ]] || return 0
    kill -9 "$pid" 2>/dev/null \
        && notify "killer" "kill -9 $plain" \
        || notify -u critical "killer" "failed to kill $pid"
    exit 0
}

run_pass() {
    local file="${PASS:-}"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        notify -u critical "pass" "PASS env var not set or file missing"
        return 1
    fi
    # Parse pass.md: entries are lines ending with "\_"; password is the
    # next non-empty line after the entry marker.
    local entries_raw src pick plain password
    entries_raw=$(grep -E '\\_$' "$file" | sed -E 's/\\_$//')
    if [ -z "$entries_raw" ]; then
        notify -u critical "pass" "no entries in $file"
        return 1
    fi
    # tv fuzzy picker.
    src='{ printf "%s\n" "← Back"; printf "%s\n" "'"$(printf '%s' "$entries_raw" | sed 's/\x27/\x27\\\x27\x27/g')"'"; }'
    pick=$(tv --source-command "$src" --input-header "Passwords" --no-sort --no-preview) || return 0
    [ -n "$pick" ] || return 0
    plain=$(printf '%s' "$pick" | sed -E 's/\x1b\[[0-9;]*m//g')
    case "$plain" in *"$BACK_PLAIN"*|"← Back") return 0 ;; esac
    pick="$plain"
    # Locate the entry then grab the following non-empty line.
    password=$(awk -v key="${pick}\\\\_" '
        $0 == key { found=1; next }
        found && NF { print; exit }
    ' "$file")
    if [ -z "$password" ]; then
        notify -u critical "pass" "no password found for $pick"
        return 1
    fi
    # xclip forks to become the X selection owner; when this script exits,
    # kitty-lister closes and SIGHUPs the process group, killing the
    # selection owner before any consumer can paste (no clipboard manager
    # is running to persist it). setsid -f detaches xclip into its own
    # session so it survives the terminal teardown.
    #
    # Do NOT use -loops 1: many X clients (notification daemons, the WM,
    # even xclip's own selection probe) request TARGETS conversion as soon
    # as ownership changes — that probe consumes the single "loop" and
    # xclip exits before the user can actually paste, so Ctrl+V yields
    # nothing. The 45s explicit clear below is the lifetime control.
    printf '%s' "$password" | setsid -f xclip -selection clipboard -i >/dev/null 2>&1
    notify "pass" "copied ${pick}; clears in 45s"
    ( sleep 45 && printf '' | setsid -f xclip -selection clipboard -i >/dev/null 2>&1 ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
    exit 0
}

run_wifi() {
    # Wi-Fi via iwd (iwctl). Requires passwordless sudo for iwctl (iwd's
    # dbus ACL restricts non-root); we use `sudo -n iwctl` throughout.
    #
    # Root-cause of prior failure: script depended on /etc/netctl/ which
    # this system does not have, and nmcli is not installed. iwd is the
    # active network stack. Falling back to the correct tool.
    local iface nets_raw pick plain ssid

    # Pick the first available wifi station.
    iface=$(sudo -n iwctl station list 2>/dev/null \
        | sed -E 's/\x1b\[[0-9;]*m//g' \
        | awk '/^-+$/{dash++; next} dash>=2 && NF>=1 && $1!="Name"{print $1; exit}')
    if [ -z "$iface" ]; then
        notify -u critical "wifi" "no iwd station found (is iwd running?)"
        gum style --border double --padding "1" --foreground "#FFD700" \
            "Wi-Fi unavailable — no iwd station" 2>/dev/null || true
        sleep 2
        return 1
    fi

    # Trigger a rescan (non-blocking best-effort).
    sudo -n iwctl station "$iface" scan >/dev/null 2>&1 || true
    sleep 1

    # Collect available networks. iwctl output has a header block + table;
    # strip ANSI, skip headers, keep lines that start with >= 2 spaces.
    nets_raw=$(sudo -n iwctl station "$iface" get-networks 2>/dev/null \
        | sed -E 's/\x1b\[[0-9;]*m//g' \
        | awk '
            /Available networks/ {inblk=1; next}
            inblk && /^--+$/ {dash++; next}
            inblk && dash>=2 && NF>=2 {
                # Lines may start with ">" (connected marker) + spaces.
                line=$0
                sub(/^[[:space:]]*>?[[:space:]]*/,"",line)
                if (line ~ /^Name/) next
                print line
            }')

    if [ -z "$nets_raw" ]; then
        notify -u critical "wifi" "no networks found after scan"
        gum style --border double --padding "1" --foreground "#FFD700" \
            "No Wi-Fi networks found" 2>/dev/null || true
        sleep 2
        return 1
    fi

    # Feed to tv. Each line: "<ssid>  <security>  <signal>"
    # We use file-based source to avoid quoting hell.
    local tmp
    tmp=$(mktemp)
    {
        printf '%s\n' "← Back"
        printf '%s\n' "$nets_raw"
    } > "$tmp"
    pick=$(tv --source-command "cat $tmp" --input-header "Wi-Fi Networks (iface: $iface)" --no-sort --no-preview)
    local rc=$?
    rm -f "$tmp"
    [ $rc -eq 0 ] || return 0
    [ -n "$pick" ] || return 0
    plain=$(printf '%s' "$pick" | sed -E 's/\x1b\[[0-9;]*m//g')
    case "$plain" in *"$BACK_PLAIN"*|"← Back") return 0 ;; esac

    # The first token(s) until a gap of 2+ spaces is the SSID. Simpler:
    # iwctl columns are whitespace-separated with single spaces inside
    # name only rarely; take all but last two fields as SSID.
    ssid=$(printf '%s' "$plain" | awk '{
        if (NF<=2) { print $0; exit }
        out=$1; for (i=2;i<=NF-2;i++) out=out" "$i; print out
    }')
    [ -n "$ssid" ] || return 0

    # Connect. Known networks connect silently; new networks need a
    # passphrase — iwctl will prompt interactively in this terminal.
    if sudo -n iwctl station "$iface" connect "$ssid" 2>/dev/null; then
        notify "wifi" "connected: $ssid"
    else
        # Interactive passphrase attempt.
        if sudo iwctl station "$iface" connect "$ssid"; then
            notify "wifi" "connected: $ssid"
        else
            notify -u critical "wifi" "failed: $ssid"
        fi
    fi
    exit 0
}

run_blue() {
    # Bluetooth with tv fuzzy picker. Shows:
    #   [connected] / [paired] / [new]  <MAC>  <Name>
    # On select:
    #   connected  -> disconnect  (toggle)
    #   paired     -> connect
    #   new        -> trust + pair + connect
    # Graceful errors for bluetoothd down / rfkill blocked.

    # Service + rfkill preflight.
    if ! systemctl is-active --quiet bluetooth 2>/dev/null; then
        notify -u critical "blue" "bluetooth service inactive"
        gum style --border double --padding "1" --foreground "#00FFFF" \
            "Bluetooth service is not running" 2>/dev/null || true
        sleep 2
        return 1
    fi
    if rfkill list bluetooth 2>/dev/null | grep -qi 'blocked: yes'; then
        notify -u critical "blue" "bluetooth blocked by rfkill"
        gum style --border double --padding "1" --foreground "#00FFFF" \
            "Bluetooth blocked (rfkill)" 2>/dev/null || true
        sleep 2
        return 1
    fi

    # Ensure adapter powered on.
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" \
        || bluetoothctl power on >/dev/null 2>&1 || true

    # Kick off background scan (non-blocking) to populate new devices.
    ( bluetoothctl --timeout 8 scan on >/dev/null 2>&1 ) &
    local scan_pid=$!

    # Give the scan a moment to discover; also allow existing cache to be used.
    sleep 3

    # Build merged device list.
    local tmp
    tmp=$(mktemp)
    {
        printf '%s\n' "← Back"
        # Connected first, then paired (not connected), then others (new).
        local connected_macs paired_macs all_lines
        connected_macs=$(bluetoothctl devices Connected 2>/dev/null | awk '/^Device /{print $2}')
        paired_macs=$(bluetoothctl devices Paired 2>/dev/null | awk '/^Device /{print $2}')
        all_lines=$(bluetoothctl devices 2>/dev/null)

        # Emit connected
        printf '%s\n' "$all_lines" | awk -v cm="$connected_macs" '
            BEGIN { n=split(cm,a,"\n"); for(i=1;i<=n;i++) c[a[i]]=1 }
            /^Device / && c[$2] {
                mac=$2; $1=""; $2=""; sub(/^  /,"");
                printf "[connected] %s  %s\n", mac, $0
            }'
        # Emit paired-but-not-connected
        printf '%s\n' "$all_lines" | awk -v cm="$connected_macs" -v pm="$paired_macs" '
            BEGIN {
                nc=split(cm,a,"\n"); for(i=1;i<=nc;i++) c[a[i]]=1
                np=split(pm,b,"\n"); for(i=1;i<=np;i++) p[b[i]]=1
            }
            /^Device / && p[$2] && !c[$2] {
                mac=$2; $1=""; $2=""; sub(/^  /,"");
                printf "[paired]    %s  %s\n", mac, $0
            }'
        # Emit new (unpaired, not connected)
        printf '%s\n' "$all_lines" | awk -v cm="$connected_macs" -v pm="$paired_macs" '
            BEGIN {
                nc=split(cm,a,"\n"); for(i=1;i<=nc;i++) c[a[i]]=1
                np=split(pm,b,"\n"); for(i=1;i<=np;i++) p[b[i]]=1
            }
            /^Device / && !p[$2] && !c[$2] {
                mac=$2; $1=""; $2=""; sub(/^  /,"");
                printf "[new]       %s  %s\n", mac, $0
            }'
    } > "$tmp"

    local pick plain
    pick=$(tv --source-command "cat $tmp" --input-header "Bluetooth (scanning… [connected]/[paired]/[new])" --no-sort --no-preview)
    local rc=$?
    rm -f "$tmp"

    # Stop background scan.
    kill "$scan_pid" 2>/dev/null || true
    bluetoothctl --timeout 1 scan off >/dev/null 2>&1 &
    disown 2>/dev/null || true

    [ $rc -eq 0 ] || return 0
    [ -n "$pick" ] || return 0
    plain=$(printf '%s' "$pick" | sed -E 's/\x1b\[[0-9;]*m//g')
    case "$plain" in *"$BACK_PLAIN"*|"← Back") return 0 ;; esac

    # Parse: "[state]  <MAC>  <Name>"
    local state mac name
    state=$(printf '%s' "$plain" | awk '{print $1}')
    mac=$(printf   '%s' "$plain" | awk '{print $2}')
    name=$(printf  '%s' "$plain" | awk '{for(i=3;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":"\n")}')
    [ -n "$mac" ] || return 0

    case "$state" in
        "[connected]")
            gum spin --title "Disconnecting $name…" -- bash -c "bluetoothctl disconnect $mac" \
                && notify "blue" "disconnected: $name" \
                || notify -u critical "blue" "disconnect failed: $name"
            ;;
        "[paired]")
            gum spin --title "Connecting $name…" -- bash -c "bluetoothctl connect $mac" \
                && notify "blue" "connected: $name" \
                || notify -u critical "blue" "connect failed: $name"
            ;;
        "[new]")
            # trust -> pair -> connect, each with spinner feedback.
            local script
            script="default-agent
power on
trust $mac
pair $mac
connect $mac
quit
"
            if gum spin --title "Trusting/pairing/connecting $name…" --show-error -- \
                bash -c "printf '%s' '$script' | bluetoothctl >/tmp/blue_$$.log 2>&1"; then
                # Re-check; bluetoothctl return code is unreliable.
                if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
                    notify "blue" "paired+connected: $name"
                else
                    local err
                    err=$(grep -Ei 'failed|error|refused' /tmp/blue_$$.log 2>/dev/null | tail -1)
                    notify -u critical "blue" "pair/connect failed: $name ${err:-}"
                fi
            else
                notify -u critical "blue" "pair/connect failed: $name"
            fi
            rm -f /tmp/blue_$$.log
            ;;
        *)
            notify -u critical "blue" "unknown state: $state"
            ;;
    esac
    exit 0
}

# --- top-level picker --------------------------------------------------------

# Main loop: after any lister returns (selection made, back picked, or Esc
# cancelled), come back to the Functions picker. Exit only when the user
# cancels the top-level tv picker itself.
while :; do
    unset_gum

    # tv (television) — fuzzy-find over the list of listers. Ad-hoc channel
    # sourced from a printf of the lister names. Icons are prefixed for
    # visual parity with the inner pickers.
    choice=$(tv \
        --source-command "printf '%s\n'   run   killer   pass 󰖩  wifi   blue" \
        --input-header "Functions" \
        --no-sort) || exit 0
    [ -n "$choice" ] || exit 0
    # Strip icon prefix; keep the last whitespace-separated token.
    choice=${choice##* }

    unset_gum
    case "$choice" in
        run)    run_dmenu ;;
        killer) run_killer ;;
        pass)   run_pass ;;
        wifi)   run_wifi ;;
        blue)   run_blue ;;
        *)      exit 0 ;;
    esac
    clear
done

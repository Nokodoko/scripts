#!/bin/bash
# lewis-layout.sh — Display layout manager for lewis (ASUS Z13 + Synaptics MST TB dock)
#
# Monitor hardware:
#   eDP-1    — built-in 2560x1600 (always present)
#   DP-8/9/10/11 — two 4K externals via MST dock (names change after dock replug)
#     LG 27GN950   — identified by having a 144Hz mode listed in xrandr
#     Standard 4K  — 60Hz only
#
# Critical: MST hub cannot drive both externals at 4K if LG is at 144Hz.
# LG MUST be set to 60Hz in 3-monitor mode or DSC negotiation fails (backlight
# only, no signal).

set -euo pipefail

log() { echo "[lewis-layout] $*" >&2; }

WALLPAPER="$HOME/Pictures/archCraft.png"
HOTSWAP="/home/n0ko/scripts/dwm-hotswap.sh"
EDPOUTPUT="eDP-1"
EDPMODE="2560x1600"
EDPRATE="180"

# ── Detect connected external outputs ─────────────────────────────────────────
# Scan all DP-* outputs that xrandr reports as connected (covers DP-8 through
# DP-11 and any future number after dock replug).

declare -a CONNECTED_DPS=()

# Free CRTCs held by stale disconnected outputs (from prior dock sessions).
# After dock replug, old DP-N outputs stay disconnected but keep their CRTC
# allocated, preventing new outputs from getting one.
while IFS= read -r line; do
    stale=$(echo "$line" | awk '{print $1}')
    log "Freeing stale CRTC on $stale"
    xrandr --output "$stale" --off 2>/dev/null || true
done < <(xrandr --query | grep -E '^DP-[0-9]+ disconnected [0-9]')

while IFS= read -r line; do
    output=$(echo "$line" | awk '{print $1}')
    CONNECTED_DPS+=("$output")
done < <(xrandr --query | grep -E '^DP-[0-9]+ connected')

log "Connected DP outputs: ${CONNECTED_DPS[*]:-none}"

# ── Identify LG (144Hz) vs standard 60Hz monitor ──────────────────────────────
# xrandr lists available modes indented under each output. We check whether
# any mode line for a given output contains a refresh rate >= 100 Hz (proxy
# for 144 Hz capability).

identify_outputs() {
    local xrandr_output
    xrandr_output=$(xrandr --query)

    LG_OUTPUT=""
    STD_OUTPUT=""

    for dp in "${CONNECTED_DPS[@]}"; do
        # Extract the block of mode lines belonging to this output.
        # Mode lines are indented (start with spaces) and appear after the
        # output header line, until the next non-indented line.
        local has_high_refresh
        has_high_refresh=$(echo "$xrandr_output" | \
            awk -v out="$dp" '
                /^[^ ]/ { found = ($1 == out) }
                found && /^ / {
                    # Mode lines: "   3840x2160  144.00+  60.00*  ..."
                    # Skip $1 (resolution like 3840x2160), check $2+ for rates
                    for (i=2; i<=NF; i++) {
                        gsub(/[*+]/, "", $i)
                        val = $i + 0
                        if (val >= 100) { print "yes"; exit }
                    }
                }
            ')

        if [[ "$has_high_refresh" == "yes" ]]; then
            LG_OUTPUT="$dp"
            log "Identified LG 144Hz output: $LG_OUTPUT"
        else
            STD_OUTPUT="$dp"
            log "Identified standard 60Hz output: $STD_OUTPUT"
        fi
    done
}

# ── Widget restart ─────────────────────────────────────────────────────────────
# Conky and glava need restarting after monitor layout changes so they
# pick up the new xinerama head numbering.

restart_widgets() {
    log "Restarting desktop widgets"
    # Kill existing widget instances
    pkill -f "system.conkyrc" 2>/dev/null || true
    pkill glava 2>/dev/null || true
    sleep 1
    # Restart
    conky -c /home/n0ko/desktop-widgets/conky/system.conkyrc -d -p 2 2>/dev/null || true
    glava --desktop &>/dev/null &
}

# ── Layout modes ───────────────────────────────────────────────────────────────

layout_3monitor() {
    log "3-monitor mode: LG=$LG_OUTPUT (forced 60Hz), STD=$STD_OUTPUT, eDP-1"

    # After dock replug, CRTCs aren't ready for a single xrandr command.
    # Configure sequentially: reset eDP-1, add each external, then reposition.
    xrandr --output "$EDPOUTPUT" --mode "$EDPMODE" --rate "$EDPRATE" --pos 0x0 --primary
    sleep 1
    xrandr --output "$LG_OUTPUT" --mode 3840x2160 --rate 60 --right-of "$EDPOUTPUT"
    sleep 1
    xrandr --output "$STD_OUTPUT" --mode 3840x2160 --rate 60 --right-of "$LG_OUTPUT"
    sleep 1
    # Final reposition to desired layout
    xrandr \
        --output "$LG_OUTPUT"   --pos 0x0 \
        --output "$STD_OUTPUT"  --pos 3840x0 \
        --output "$EDPOUTPUT"   --pos 1280x2160

    feh --bg-fill "$WALLPAPER"
    # apply-multi.sh resets system.conkyrc to eDP-1 dimensions (2540 wide)
    # so the lua-centered circular gauges land on the visible region of
    # eDP-1; without this, switching from livingroom/mobile leaves a stale
    # wider minimum_width and gauges render off-center.
    /home/n0ko/desktop-widgets/apply-multi.sh &
    "$HOTSWAP" pertag-multi
}

layout_1monitor() {
    log "1-monitor mode: eDP-1 only"

    xrandr \
        --output "$EDPOUTPUT" --mode "$EDPMODE" --rate "$EDPRATE" \
                              --pos 0x0 --primary

    # Explicitly disable any lingering DP outputs
    for dp in $(xrandr --query | grep -E '^DP-[0-9]+ ' | awk '{print $1}'); do
        xrandr --output "$dp" --off
    done

    feh --bg-fill "$WALLPAPER"
    restart_widgets
    "$HOTSWAP" pertag
}

layout_2monitor() {
    local ext="$1"
    log "2-monitor mobile mode: eDP-1 primary above, external=$ext as 2560x720 strip below"

    # Mobile layout: eDP-1 primary at origin, external as 2560x720 strip below
    # Matches ~/.screenlayout/mobile.sh
    xrandr \
        --output "$EDPOUTPUT" --mode "$EDPMODE"  --rate "$EDPRATE" \
                              --pos 0x0 --primary --rotate normal \
        --output "$ext"       --mode 2560x720 --rate 60 \
                              --pos 0x1600 --rotate normal

    feh --bg-fill "$WALLPAPER"
    "$HOTSWAP" mobile
    # apply-mobile.sh restarts glava/conky with mobile geometry
    /home/n0ko/desktop-widgets/apply-mobile.sh &
}

# ── Dispatch ───────────────────────────────────────────────────────────────────

case "${#CONNECTED_DPS[@]}" in
    0)
        log "No external monitors detected."
        layout_1monitor
        ;;
    1)
        identify_outputs
        layout_2monitor "${CONNECTED_DPS[0]}"
        ;;
    2)
        identify_outputs
        if [[ -z "$LG_OUTPUT" || -z "$STD_OUTPUT" ]]; then
            log "WARNING: Could not distinguish LG from standard monitor."
            log "Falling back: treating ${CONNECTED_DPS[0]} as LG, ${CONNECTED_DPS[1]} as STD."
            LG_OUTPUT="${CONNECTED_DPS[0]}"
            STD_OUTPUT="${CONNECTED_DPS[1]}"
        fi
        layout_3monitor
        ;;
    *)
        log "ERROR: Unexpected number of external outputs (${#CONNECTED_DPS[@]}). Aborting."
        exit 1
        ;;
esac

log "Layout applied."

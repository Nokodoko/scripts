#!/bin/bash
# mobile-layout.sh — Apply eDP-1 + single external monitor layout (vertical stack).
#
# Detects the connected external output dynamically instead of hardcoding a
# name (the old arandr-generated ~/.screenlayout/mobile.sh hardcoded DP-1,
# which broke silently once the external enumerated as DP-2).
#
# Layout: eDP-1 primary 2560x1600 at 0x0 (top), external at 0x1600 (below).
# This is a vertical stack — NEVER --right-of.

set -euo pipefail

log() { echo "[mobile-layout] $*" >&2; }

EDPOUTPUT="eDP-1"
EDPMODE="2560x1600"
EXTMODE="2560x720"

# Detect the connected external: first DP-*/HDMI-* output xrandr reports as
# connected. eDP-1 never matches this pattern, so no extra exclusion needed.
EXT=$(xrandr --query 2>/dev/null | grep -E '^(DP|HDMI)-[0-9]+ connected' | head -1 | awk '{print $1}')

if [[ -z "$EXT" ]]; then
    log "ERROR: no connected DP-*/HDMI-* output found"
    notify-send "mobile-layout" "No external monitor detected" --urgency=critical
    exit 1
fi

log "Detected external output: $EXT"

# Use the native 2560x720 mode if the external actually lists it; otherwise
# fall back to its preferred mode, still positioned below eDP-1.
if xrandr --query 2>/dev/null | awk -v out="$EXT" '/^[^ ]/{f=($1==out)} f && /^ /{print $1}' | grep -qx "$EXTMODE"; then
    EXT_MODE_ARGS=(--mode "$EXTMODE")
else
    log "WARNING: $EXT has no $EXTMODE mode, falling back to --preferred"
    EXT_MODE_ARGS=(--preferred)
fi

# Power off any other output that's currently active (has a CRTC/geometry)
# but is neither eDP-1 nor the detected external — e.g. a phantom monitor
# left enabled from a previous dock session.
OTHER_ACTIVE=$(xrandr --query 2>/dev/null \
    | grep -E '^[A-Za-z0-9-]+ connected (primary )?[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' \
    | awk '{print $1}' | grep -vx -e "$EDPOUTPUT" -e "$EXT" || true)

XRANDR_ARGS=(
    --output "$EDPOUTPUT" --primary --mode "$EDPMODE" --pos 0x0 --rotate normal
    --output "$EXT" "${EXT_MODE_ARGS[@]}" --pos 0x1600 --rotate normal
)
for out in $OTHER_ACTIVE; do
    log "Powering off stale active output: $out"
    XRANDR_ARGS+=(--output "$out" --off)
done

if ! xrandr "${XRANDR_ARGS[@]}"; then
    log "ERROR: xrandr failed applying eDP-1+$EXT layout"
    notify-send "mobile-layout" "xrandr failed applying eDP-1+$EXT layout" --urgency=critical
    exit 1
fi

log "Applied: $EDPOUTPUT ${EDPMODE}+0+0 (primary), $EXT below at 0x1600"

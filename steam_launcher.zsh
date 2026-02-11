#!/usr/bin/env zsh
# Steam Game Launcher - reads local Steam library (all library folders)

# Ensure DISPLAY is set
export DISPLAY=${DISPLAY:-:0}

STEAM_ROOT="$HOME/.local/share/Steam"
LIBRARY_VDF="$STEAM_ROOT/steamapps/libraryfolders.vdf"

# Check if Steam directory exists
if [[ ! -f "$LIBRARY_VDF" ]]; then
    notify-send "Steam Launcher" "Steam library config not found" --urgency=critical
    echo "Steam library config not found: $LIBRARY_VDF"
    read -k 1
    exit 1
fi

# Get all library paths from libraryfolders.vdf
LIBRARY_PATHS=($(grep '"path"' "$LIBRARY_VDF" | sed 's/.*"path"[[:space:]]*"\(.*\)".*/\1/'))

if [[ ${#LIBRARY_PATHS[@]} -eq 0 ]]; then
    LIBRARY_PATHS=("$STEAM_ROOT")
fi

# Parse installed games from all library folders
GAMES=""
for lib_path in "${LIBRARY_PATHS[@]}"; do
    steamapps="$lib_path/steamapps"
    if [[ -d "$steamapps" ]]; then
        for acf in "$steamapps"/appmanifest_*.acf; do
            if [[ -f "$acf" ]]; then
                appid=$(grep '"appid"' "$acf" | head -1 | sed 's/.*"appid"[[:space:]]*"\([0-9]*\)".*/\1/')
                name=$(grep '"name"' "$acf" | head -1 | sed 's/.*"name"[[:space:]]*"\(.*\)".*/\1/')
                if [[ -n "$appid" && -n "$name" ]]; then
                    # Filter out Steam tools/runtimes
                    case "$name" in
                        *"Steam Linux Runtime"*|*"Proton"*|*"Steamworks"*|*"Redistributables"*|*"SteamVR"*)
                            ;;
                        *)
                            GAMES+="$appid - $name\n"
                            ;;
                    esac
                fi
            fi
        done
    fi
done

GAMES=$(echo -e "$GAMES" | sort -t'-' -k2 | grep -v '^$')

if [[ -z "$GAMES" ]]; then
    notify-send "Steam Launcher" "No installed games found" --urgency=normal
    echo "No installed games found."
    read -k 1
    exit 1
fi

# Use gum to pick a game
SELECTION=$(echo "$GAMES" | gum filter --placeholder "Select a game to launch...")

if [[ -z "$SELECTION" ]]; then
    echo "No game selected."
    exit 0
fi

# Extract AppID and name
APPID=$(echo "$SELECTION" | cut -d'-' -f1 | tr -d ' ')
GAME_NAME=$(echo "$SELECTION" | cut -d'-' -f2- | sed 's/^ //')

if [[ -n "$APPID" ]]; then
    echo "Launching: $GAME_NAME (AppID: $APPID)"
    notify-send "Launching Game" "$GAME_NAME" --urgency=normal --app-name="Steam Launcher"

    # Count windows before launch
    INITIAL_COUNT=$(xdotool search --name "" 2>/dev/null | wc -l)

    # Launch the game - use nohup to survive terminal close
    nohup steam steam://run/$APPID >/dev/null 2>&1 &

    # Start background watcher to switch to tag 7 when game window appears
    setsid /home/n0ko/scripts/wait_for_game.zsh "$INITIAL_COUNT" &

    sleep 1
else
    notify-send "Steam Launcher" "Could not extract AppID" --urgency=critical
    echo "Could not extract AppID."
    read -k 1
    exit 1
fi

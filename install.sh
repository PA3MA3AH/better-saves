#!/bin/bash
set -e

echo "============================================"
echo "  BetterSaves v1.4"
echo "  The Coffin of Andy and Leyley"
echo "============================================"
echo ""

GAME_NAME="The Coffin of Andy and Leyley"
GAME_PATH=""

# --- Search standard Steam paths ---
SEARCH_PATHS=(
    "$HOME/.steam/steam/steamapps/common/$GAME_NAME"
    "$HOME/.local/share/Steam/steamapps/common/$GAME_NAME"
    "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/common/$GAME_NAME"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/$GAME_NAME"
    "/usr/share/steam/steamapps/common/$GAME_NAME"
)

# --- Also search all Steam library folders ---
while IFS= read -r -d '' vdf; do
    while IFS= read -r line; do
        if [[ "$line" =~ \"path\" ]]; then
            p=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/' | sed 's|\\\\|/|g')
            p="${p//\\//}"
            SEARCH_PATHS+=("$p/steamapps/common/$GAME_NAME")
        fi
    done < "$vdf"
done < <(find "$HOME" -maxdepth 6 -name "libraryfolders.vdf" -print0 2>/dev/null)

# --- Also search /data /mnt /media partitions ---
for base in /data /mnt /media; do
    if [ -d "$base" ]; then
        while IFS= read -r -d '' p; do
            SEARCH_PATHS+=("$p")
        done < <(find "$base" -maxdepth 6 -name "$GAME_NAME" -type d -print0 2>/dev/null)
    fi
done

# --- Remove duplicates ---
SEARCH_PATHS=($(printf "%s\n" "${SEARCH_PATHS[@]}" | sort -u))

# --- Search for game ---
for p in "${SEARCH_PATHS[@]}"; do
    if [ -f "$p/www/js/plugins.js" ]; then
        GAME_PATH="$p"
        break
    fi
done

# --- Ask user if not found ---
if [ -z "$GAME_PATH" ]; then
    echo "[!] Could not find the game automatically."
    echo ""
    echo "Please enter the full path to the game folder:"
    echo "Example: /home/user/.steam/steam/steamapps/common/The Coffin of Andy and Leyley"
    echo ""
    read -r -p "Path: " GAME_PATH
fi

# --- Expand ~ if used ---
GAME_PATH="${GAME_PATH/#\~/$HOME}"

# --- Validate ---
if [ ! -f "$GAME_PATH/www/js/plugins.js" ]; then
    echo ""
    echo "[ERROR] Game not found at: $GAME_PATH"
    echo "Make sure the game is installed and the path is correct."
    echo ""
    echo "Tip: You can find the game path with:"
    echo "  find ~ -name 'plugins.js' -path '*/www/js/*' 2>/dev/null"
    exit 1
fi

echo "[OK] Game found: $GAME_PATH"
echo ""

# --- Check write permissions ---
if [ ! -w "$GAME_PATH/www/js/plugins.js" ]; then
    echo "[ERROR] No write permission for plugins.js"
    echo "Try running with sudo or check file permissions."
    exit 1
fi

# --- Backup ---
echo "[*] Backing up plugins.js..."
cp "$GAME_PATH/www/js/plugins.js" "$GAME_PATH/www/js/plugins.js.bak"
echo "[OK] Backup saved: plugins.js.bak"

# --- Copy plugin ---
echo "[*] Installing BetterSaves.js..."
mkdir -p "$GAME_PATH/www/js/plugins/"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/BetterSaves.js" ]; then
    echo "[ERROR] BetterSaves.js not found in $SCRIPT_DIR"
    echo "Make sure the script is in the same folder as BetterSaves.js"
    exit 1
fi

cp "$SCRIPT_DIR/BetterSaves.js" "$GAME_PATH/www/js/plugins/BetterSaves.js"
echo "[OK] BetterSaves.js installed"

# --- Register in plugins.js ---
PLUGINS_JS="$GAME_PATH/www/js/plugins.js"

if grep -q '"BetterSaves"' "$PLUGINS_JS"; then
    echo "[OK] Plugin already registered in plugins.js"
else
    echo "[*] Registering plugin..."
    
    TMP_FILE=$(mktemp)
    
    # Read file, find last occurrence of "]", add new plugin before it
    python3 -c "
import json, sys

with open('$PLUGINS_JS', 'r', encoding='utf-8') as f:
    content = f.read().strip()

# Remove trailing ]; if exists
content = content.rstrip(';').rstrip()
if content.endswith(']'):
    content = content[:-1].rstrip()
    # Add comma if needed
    if content and not content.endswith('['):
        content += ','
    
    # Add new plugin
    new_plugin = {
        'name': 'BetterSaves',
        'status': True,
        'description': 'Better saves v1.4',
        'parameters': {
            'language': 'EN',
            'showMapId': 'true'
        }
    }
    
    content += '\n  ' + json.dumps(new_plugin, indent=2) + '\n];\n'

with open('$TMP_FILE', 'w', encoding='utf-8') as f:
    f.write(content)
" 2>/dev/null

    if [ $? -eq 0 ] && [ -s "$TMP_FILE" ]; then
        # Validate JSON
        if python3 -c "import json; json.load(open('$TMP_FILE'))" 2>/dev/null; then
            mv "$TMP_FILE" "$PLUGINS_JS"
            echo "[OK] Plugin registered"
        else
            rm "$TMP_FILE"
            echo "[WARNING] Failed to create valid JSON"
            echo "You can register manually:"
            echo "  Add before the last ']' in $PLUGINS_JS:"
            echo '  ,{"name":"BetterSaves","status":true,"description":"Better saves v1.4","parameters":{"language":"EN","showMapId":"true"}}'
        fi
    else
        # Fallback to sed method
        python3 -c "exit(0)" 2>/dev/null
        if [ $? -eq 0 ]; then
            # Try simpler approach
            sed -i.bak2 's/];$/  {"name":"BetterSaves","status":true,"description":"Better saves v1.4","parameters":{"language":"EN","showMapId":"true"}}\n];/' "$PLUGINS_JS"
            echo "[OK] Plugin registered (fallback method)"
        else
            echo "[WARNING] Python3 not found, manual registration required"
            echo "  Add before the last ']' in $PLUGINS_JS:"
            echo '  ,{"name":"BetterSaves","status":true,"description":"Better saves v1.4","parameters":{"language":"EN","showMapId":"true"}}'
        fi
    fi
    
    rm -f "$TMP_FILE"
fi

echo ""
echo "============================================"
echo "  Done! Launch the game via Steam."
echo "  To change language: Options → Save mod language"
echo "  To uninstall: run uninstall.sh"
echo "============================================"
echo ""

#!/bin/bash
echo "============================================"
echo "  BetterSaves v1.1 - Installer"
echo "  The Coffin of Andy and Leyley"
echo "============================================"
echo ""

GAME_NAME="The Coffin of Andy and Leyley"
CANDIDATES=(
    "$HOME/.steam/steam/steamapps/common/$GAME_NAME"
    "$HOME/.local/share/Steam/steamapps/common/$GAME_NAME"
    "/data/SteamLibrary/steamapps/common/$GAME_NAME"
    "/mnt/SteamLibrary/steamapps/common/$GAME_NAME"
)

# Search all Steam library folders
while IFS= read -r line; do
    if [[ "$line" == *"path"* ]]; then
        p=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/' | sed 's/\\\\/\//g')
        CANDIDATES+=("$p/steamapps/common/$GAME_NAME")
    fi
done < <(find "$HOME/.steam" -name "libraryfolders.vdf" 2>/dev/null -exec cat {} \;)

GAME_PATH=""
for p in "${CANDIDATES[@]}"; do
    if [ -f "$p/www/js/plugins.js" ]; then
        GAME_PATH="$p"
        break
    fi
done

if [ -z "$GAME_PATH" ]; then
    echo "[!] Game not found automatically."
    echo "Please enter the full path to the game folder:"
    read -r GAME_PATH
fi

if [ ! -f "$GAME_PATH/www/js/plugins.js" ]; then
    echo "[ERROR] plugins.js not found in: $GAME_PATH"
    exit 1
fi

echo "[OK] Game found: $GAME_PATH"
echo ""

# Backup
cp "$GAME_PATH/www/js/plugins.js" "$GAME_PATH/www/js/plugins.js.bak"
echo "[OK] Backup saved as plugins.js.bak"

# Copy plugin
mkdir -p "$GAME_PATH/www/js/plugins/"
cp "$(dirname "$0")/BetterSaves.js" "$GAME_PATH/www/js/plugins/BetterSaves.js"
echo "[OK] BetterSaves.js copied"

# Register if not already
if grep -q "BetterSaves" "$GAME_PATH/www/js/plugins.js"; then
    echo "[OK] Plugin already registered, skipping."
else
    python3 -c "
import sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    c = f.read()
entry = ',{\"name\":\"BetterSaves\",\"status\":true,\"description\":\"Better saves v1.1\",\"parameters\":{\"language\":\"RU\",\"showMapId\":\"true\"}}'
c = c.rstrip().rstrip(';').rstrip(']') + entry + '\n];'
with open(path, 'w', encoding='utf-8') as f:
    f.write(c)
print('[OK] Plugin registered')
" "$GAME_PATH/www/js/plugins.js"
fi

echo ""
echo "============================================"
echo "  Done! Launch the game via Steam."
echo "  Language: Options menu -> Save mod language"
echo "============================================"

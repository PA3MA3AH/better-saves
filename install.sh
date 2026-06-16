#!/bin/bash
set -e

echo "============================================"
echo "  BetterSaves v1.4"
echo "  The Coffin of Andy and Leyley"
echo "============================================"
echo ""

GAME_NAME="The Coffin of Andy and Leyley"
GAME_PATH=""

SEARCH_PATHS=(
    "$HOME/.steam/steam/steamapps/common/$GAME_NAME"
    "$HOME/.local/share/Steam/steamapps/common/$GAME_NAME"
    "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/common/$GAME_NAME"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/$GAME_NAME"
    "/usr/share/steam/steamapps/common/$GAME_NAME"
)

if [ -d "$HOME" ]; then
    while IFS= read -r -d '' vdf; do
        while IFS= read -r line; do
            if [[ "$line" =~ \"path\" ]]; then
                p=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/' | sed 's|\\\\|/|g')
                SEARCH_PATHS+=("${p}/steamapps/common/$GAME_NAME")
            fi
        done < "$vdf"
    done < <(find "$HOME" -maxdepth 5 \( -name ".*" -a ! -name ".steam" -a ! -name ".local" -a ! -name ".var" \) -prune -o -name "libraryfolders.vdf" -print0 2>/dev/null)
fi

for base in /data /mnt /media; do
    if [ -d "$base" ]; then
        while IFS= read -r -d '' p; do
            SEARCH_PATHS+=("$p")
        done < <(find "$base" -maxdepth 3 -name "$GAME_NAME" -type d -print0 2>/dev/null)
    fi
done

for p in "${SEARCH_PATHS[@]}"; do
    if [ -f "$p/www/js/plugins.js" ]; then
        GAME_PATH="$p"
        break
    fi
done

if [ -z "$GAME_PATH" ]; then
    echo "[!] Could not find the game automatically."
    echo ""
    echo "Please enter the full path to the game folder:"
    echo "Example: /home/user/.steam/steam/steamapps/common/The Coffin of Andy and Leyley"
    echo ""
    read -r -p "Path: " GAME_PATH
fi

GAME_PATH="${GAME_PATH/#\~/$HOME}"

if [ ! -f "$GAME_PATH/www/js/plugins.js" ]; then
    echo ""
    echo "[ERROR] Game not found at: $GAME_PATH"
    echo "Make sure the game is installed and the path is correct."
    exit 1
fi

echo "[OK] Game found: $GAME_PATH"
echo ""

PLUGINS_JS="$GAME_PATH/www/js/plugins.js"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/BetterSaves.js" ]; then
    echo "[ERROR] BetterSaves.js not found in $SCRIPT_DIR"
    exit 1
fi

echo "[*] Backing up plugins.js..."
cp "$PLUGINS_JS" "${PLUGINS_JS}.bak"

echo "[*] Installing BetterSaves.js..."
mkdir -p "$GAME_PATH/www/js/plugins/"
cp "$SCRIPT_DIR/BetterSaves.js" "$GAME_PATH/www/js/plugins/BetterSaves.js"

echo "[*] Registering plugin..."

node -e "
const fs = require('fs');
const filePath = '$PLUGINS_JS';

let content = fs.readFileSync(filePath, 'utf8');

if (content.includes('\"BetterSaves\"')) {
    console.log('[OK] Plugin already registered');
    process.exit(0);
}

const lastIndex = content.lastIndexOf(']');
if (lastIndex === -1) {
    console.error('[ERROR] Could not find valid array structure in plugins.js');
    process.exit(1);
}

const newPluginStr = JSON.stringify({
    name: 'BetterSaves',
    status: true,
    description: 'Better saves v1.4',
    parameters: {
        language: 'EN',
        showMapId: 'true'
    }
}, null, 4);

let before = content.substring(0, lastIndex).trim();
if (before.endsWith(',')) {
    before = before.slice(0, -1);
}

const isArrayEmpty = before.endsWith('[');
const separator = isArrayEmpty ? '\n' : ',\n';

const output = before + separator + newPluginStr + '\n];\n';

try {
    fs.writeFileSync(filePath, output, 'utf8');
    console.log('[OK] Plugin successfully registered');
} catch (e) {
    console.error('[ERROR] Failed to write to plugins.js:', e.message);
    process.exit(1);
}
"

echo ""
echo "============================================"
echo "  Done! Launch the game via Steam."
echo "  To change language: Options -> Save mod language"
echo "============================================"
echo ""

#!/bin/bash
echo "============================================"
echo "  BetterSaves v1.1"
echo "  The Coffin of Andy and Leyley"
echo "============================================"
echo ""

GAME_NAME="The Coffin of Andy and Leyley"
GAME_PATH=""

# --- Search standard Steam paths ---
SEARCH_PATHS=(
    "$HOME/.steam/steam/steamapps/common/$GAME_NAME"
    "$HOME/.local/share/Steam/steamapps/common/$GAME_NAME"
    "/usr/share/steam/steamapps/common/$GAME_NAME"
)

# --- Also search all Steam library folders ---
for vdf in $(find "$HOME" -maxdepth 6 -name "libraryfolders.vdf" 2>/dev/null); do
    while IFS= read -r line; do
        if [[ "$line" =~ \"path\" ]]; then
            p=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/' | tr '\\' '/')
            SEARCH_PATHS+=("$p/steamapps/common/$GAME_NAME")
        fi
    done < "$vdf"
done

# --- Also search /data /mnt /media partitions ---
for base in /data /mnt /media; do
    for p in $(find "$base" -maxdepth 6 -name "The Coffin of Andy and Leyley" -type d 2>/dev/null); do
        SEARCH_PATHS+=("$p")
    done
done

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

# --- Validate ---
if [ ! -f "$GAME_PATH/www/js/plugins.js" ]; then
    echo ""
    echo "[ERROR] Game not found at: $GAME_PATH"
    echo "Make sure the game is installed and the path is correct."
    exit 1
fi

echo "[OK] Game found: $GAME_PATH"
echo ""

# --- Backup ---
cp "$GAME_PATH/www/js/plugins.js" "$GAME_PATH/www/js/plugins.js.bak"
echo "[OK] Backup saved: plugins.js.bak"

# --- Copy plugin ---
mkdir -p "$GAME_PATH/www/js/plugins/"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/BetterSaves.js" "$GAME_PATH/www/js/plugins/BetterSaves.js"
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to copy BetterSaves.js"
    exit 1
fi
echo "[OK] BetterSaves.js installed"

# --- Register in plugins.js (safe method) ---
PLUGINS_JS="$GAME_PATH/www/js/plugins.js"

if grep -q '"BetterSaves"' "$PLUGINS_JS"; then
    echo "[OK] Plugin already registered in plugins.js"
else
    TMP_FILE=$(mktemp)
    
    # Удаляем завершающую "];" с пробелами/переводами строк
    sed -E ':a; /];[[:space:]]*$/!{N;ba}; s/];[[:space:]]*$//g' "$PLUGINS_JS" > "$TMP_FILE"
    
    # Добавляем запятую, если нужно
    LAST_CHAR=$(tail -c 2 "$TMP_FILE" | tr -d '\n')
    if [ "$LAST_CHAR" != "," ] && [ "$LAST_CHAR" != "[" ]; then
        echo "," >> "$TMP_FILE"
    fi
    
    # Вставляем новый плагин
    echo '  {"name":"BetterSaves","status":true,"description":"Better saves v1.1","parameters":{"language":"RU","showMapId":"true"}}' >> "$TMP_FILE"
    echo "];" >> "$TMP_FILE"
    
    mv "$TMP_FILE" "$PLUGINS_JS"
    echo "[OK] Plugin registered"
fi

echo ""
echo "============================================"
echo "  Done! Launch the game via Steam."
echo "  To change language: Options menu"
echo "  To uninstall: run uninstall.sh"
echo "============================================"

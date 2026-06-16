#!/bin/bash
set -e

echo "============================================"
echo "  BetterSaves - Uninstaller"
echo "============================================"
echo ""

GAME_NAME="The Coffin of Andy and Leyley"
GAME_PATH=""

# --- Search paths ---
SEARCH_PATHS=(
    "$HOME/.steam/steam/steamapps/common/$GAME_NAME"
    "$HOME/.local/share/Steam/steamapps/common/$GAME_NAME"
    "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/common/$GAME_NAME"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/$GAME_NAME"
    "/usr/share/steam/steamapps/common/$GAME_NAME"
)

# --- Also search libraryfolders.vdf ---
while IFS= read -r -d '' vdf; do
    while IFS= read -r line; do
        if [[ "$line" =~ \"path\" ]]; then
            p=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/' | sed 's|\\\\|/|g')
            SEARCH_PATHS+=("$p/steamapps/common/$GAME_NAME")
        fi
    done < "$vdf"
done < <(find "$HOME" -maxdepth 6 -name "libraryfolders.vdf" -print0 2>/dev/null)

# --- Search mounted drives ---
for base in /data /mnt /media; do
    if [ -d "$base" ]; then
        while IFS= read -r -d '' p; do
            SEARCH_PATHS+=("$p")
        done < <(find "$base" -maxdepth 6 -name "$GAME_NAME" -type d -print0 2>/dev/null)
    fi
done

# --- Find game ---
for p in "${SEARCH_PATHS[@]}"; do
    if [ -f "$p/www/js/plugins.js" ]; then
        GAME_PATH="$p"
        break
    fi
done

# --- Ask user if not found ---
if [ -z "$GAME_PATH" ]; then
    echo "[!] Game not found automatically."
    echo ""
    echo "You can find it with:"
    echo "  find ~ -name 'plugins.js' -path '*/www/js/*' 2>/dev/null"
    echo ""
    read -r -p "Enter full path to game folder: " GAME_PATH
fi

# --- Expand ~ ---
GAME_PATH="${GAME_PATH/#\~/$HOME}"

# --- Validate ---
if [ ! -f "$GAME_PATH/www/js/plugins.js" ]; then
    echo ""
    echo "[ERROR] plugins.js not found at:"
    echo "  $GAME_PATH/www/js/plugins.js"
    echo ""
    echo "Make sure the path is correct."
    exit 1
fi

echo "[OK] Game found: $GAME_PATH"
echo ""

# --- Remove BetterSaves.js ---
if [ -f "$GAME_PATH/www/js/plugins/BetterSaves.js" ]; then
    rm -f "$GAME_PATH/www/js/plugins/BetterSaves.js"
    echo "[OK] BetterSaves.js removed"
else
    echo "[INFO] BetterSaves.js not found"
fi

# --- Remove empty plugins directory ---
if [ -d "$GAME_PATH/www/js/plugins" ] && [ -z "$(ls -A "$GAME_PATH/www/js/plugins" 2>/dev/null)" ]; then
    rmdir "$GAME_PATH/www/js/plugins" 2>/dev/null
fi

# --- Restore backup ---
if [ -f "$GAME_PATH/www/js/plugins.js.bak" ]; then
    echo "[*] Restoring plugins.js from backup..."
    cp "$GAME_PATH/www/js/plugins.js.bak" "$GAME_PATH/www/js/plugins.js"
    mv "$GAME_PATH/www/js/plugins.js.bak" "$GAME_PATH/www/js/plugins.js.bak.old"
    echo "[OK] plugins.js restored (backup kept as plugins.js.bak.old)"
elif [ -f "$GAME_PATH/www/js/plugins.js.bak2" ]; then
    echo "[*] Restoring plugins.js from backup..."
    cp "$GAME_PATH/www/js/plugins.js.bak2" "$GAME_PATH/www/js/plugins.js"
    mv "$GAME_PATH/www/js/plugins.js.bak2" "$GAME_PATH/www/js/plugins.js.bak2.old"
    echo "[OK] plugins.js restored (backup kept as plugins.js.bak2.old)"
else
    # --- Manual removal with Python ---
    echo "[*] No backup found, removing BetterSaves entry manually..."
    
    if command -v python3 &>/dev/null; then
        python3 -c "
import json

with open('$GAME_PATH/www/js/plugins.js', 'r', encoding='utf-8') as f:
    content = f.read().strip()

# Remove trailing ];
content = content.rstrip(';').rstrip()
if content.endswith(']'):
    content = content[:-1].rstrip()
    
    # Parse as JSON array
    try:
        plugins = json.loads(content + ']')
    except:
        print('ERROR: Could not parse plugins.js')
        exit(1)
    
    # Filter out BetterSaves
    plugins = [p for p in plugins if p.get('name') != 'BetterSaves']
    
    # Write back
    with open('$GAME_PATH/www/js/plugins.js', 'w', encoding='utf-8') as f:
        json.dump(plugins, f, indent=2)
        f.write('\n')
    
    print('OK')
" 2>/dev/null && echo "[OK] Plugin entry removed" || {
        echo "[WARNING] Could not auto-remove plugin entry"
        echo ""
        echo "Please manually edit this file:"
        echo "  $GAME_PATH/www/js/plugins.js"
        echo ""
        echo "Find and remove the object with \"name\": \"BetterSaves\""
    }
    else
        # --- Sed fallback ---
        sed -i.bak-tmp '/"BetterSaves"/d' "$GAME_PATH/www/js/plugins.js" 2>/dev/null && {
            # Clean up trailing commas
            sed -i 's/,\s*\]/]/g' "$GAME_PATH/www/js/plugins.js"
            sed -i 's/\[\s*,/[/g' "$GAME_PATH/www/js/plugins.js"
            rm -f "$GAME_PATH/www/js/plugins.js.bak-tmp"
            echo "[OK] Plugin entry removed (sed method)"
        } || {
            rm -f "$GAME_PATH/www/js/plugins.js.bak-tmp"
            echo "[WARNING] Could not auto-remove plugin entry"
            echo ""
            echo "Please manually edit:"
            echo "  $GAME_PATH/www/js/plugins.js"
        }
    fi
fi

echo ""
echo "============================================"
echo "  Uninstall complete!"
echo "  Your save files are NOT affected."
echo "============================================"
echo ""

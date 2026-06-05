#!/bin/bash
echo "BetterSaves - Uninstaller"
echo ""

GAME_NAME="The Coffin of Andy and Leyley"
GAME_PATH=""

for p in \
    "$HOME/.steam/steam/steamapps/common/$GAME_NAME" \
    "$HOME/.local/share/Steam/steamapps/common/$GAME_NAME" \
    "/data/SteamLibrary/steamapps/common/$GAME_NAME"; do
    if [ -f "$p/www/js/plugins.js" ]; then GAME_PATH="$p"; break; fi
done

if [ -z "$GAME_PATH" ]; then
    read -r -p "Enter game path: " GAME_PATH
fi

if [ -f "$GAME_PATH/www/js/plugins.js.bak" ]; then
    cp "$GAME_PATH/www/js/plugins.js.bak" "$GAME_PATH/www/js/plugins.js"
    rm "$GAME_PATH/www/js/plugins.js.bak"
    echo "[OK] plugins.js restored from backup"
fi

rm -f "$GAME_PATH/www/js/plugins/BetterSaves.js"
echo "[OK] BetterSaves.js removed"
echo "[OK] Done. Your save files are NOT affected."

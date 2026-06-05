# BetterSaves — improved save system mod
**Mod for [The Coffin of Andy and Leyley](https://store.steampowered.com/app/2378900)**
![screenshot](screenshots/preview.png)
## What it adds
- **Episode label** on each slot — Episode 1, 2, 3 (pt.1), 4
- **Notes** — add custom text to each save ("car choice", "true end", etc.)
- **Edit note** without overwriting the save file
- **Copy slots** — duplicate any save to another slot
- **Delete** saves directly from the menu
- **Language** toggle in game Options (RU / EN)
- Old saves are **not broken** — episode is detected automatically on first launch
---
## Installation
### Windows
1. [Download the latest release](../../releases/latest) and unzip anywhere
2. Right-click `install.bat` → **Run as administrator**
3. Launch the game via Steam as usual ✓

> ⚠️ Administrator rights are required because the game is typically installed in `Program Files`.

### Linux
1. [Download the latest release](../../releases/latest) and unzip
2. Open a terminal in the folder
3. Run:
   ```bash
   chmod +x install.sh && ./install.sh
   ```
4. Launch the game via Steam as usual ✓
---
## Uninstall
Run `uninstall.bat` (Windows) or `uninstall.sh` (Linux).  
Your save files will not be affected.
---
## Change language
`Options` → **"Save mod language"** → press Enter or ←/→
---
## Compatibility
| | |
|---|---|
| Windows | ✅ |
| Linux | ✅ |
| macOS | ✅ (via install.sh) |
| Game version | 3.0.x and above |
| Existing saves | ✅ not broken |
---
## If automatic install doesn't work
1. Download `BetterSaves.js`
2. Place it into `/The Coffin of Andy and Leyley/www/js/plugins/`
3. Open `/The Coffin of Andy and Leyley/www/js/plugins.js` in any text editor
4. Find the closing `];` at the end of the file and insert before it:
   ```
   ,{"name":"BetterSaves","status":true,"description":"Better saves v1.1","parameters":{"language":"RU","showMapId":"true"}}
   ```
5. Save the file and launch the game via Steam ✓
---
## Found a bug?
In the load menu, select a save → **"Report bug"** — the info will be copied to clipboard.  
Open an [Issue](../../issues/new) and paste it with a description.
---
## Credits
- **PA3MA3AH** — development

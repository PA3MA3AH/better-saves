@echo off
chcp 65001 >nul
title BetterSaves Installer

echo ============================================
echo BetterSaves v1.7.16
echo The Coffin of Andy and Leyley
echo ============================================
echo.

set GAME_PATH=

for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
if defined GAME_PATH goto :validate

for /f "tokens=2*" %%a in ('reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
if defined GAME_PATH goto :validate

for %%d in (C D E F G H) do (
  for %%p in (
    "%%d:\Program Files (x86)\Steam\steamapps\common\The Coffin of Andy and Leyley"
    "%%d:\Program Files\Steam\steamapps\common\The Coffin of Andy and Leyley"
    "%%d:\Steam\steamapps\common\The Coffin of Andy and Leyley"
    "%%d:\SteamLibrary\steamapps\common\The Coffin of Andy and Leyley"
    "%%d:\Games\steamapps\common\The Coffin of Andy and Leyley"
  ) do (
    if exist "%%~p\www\js\plugins.js" (
      set GAME_PATH=%%~p
      goto :validate
    )
  )
)

echo [!] Could not find the game automatically.
echo.
echo Please enter the full path to the game folder.
echo Example: C:\Program Files (x86)\Steam\steamapps\common\The Coffin of Andy and Leyley
echo.
set /p GAME_PATH="Path: "
set GAME_PATH=%GAME_PATH:"=%

if not exist "%GAME_PATH%\www\js\plugins.js" (
  echo.
  echo [ERROR] Game not found at: %GAME_PATH%
  echo Make sure the game is installed and the path is correct.
  echo.
  pause
  exit /b 1
)

:validate
echo [OK] Game found: %GAME_PATH%
echo.

echo [*] Backing up plugins.js...
copy /y "%GAME_PATH%\www\js\plugins.js" "%GAME_PATH%\www\js\plugins.js.bak" >nul
if errorlevel 1 (
  echo [ERROR] Failed to backup plugins.js
  pause
  exit /b 1
)
echo [OK] Backup saved: plugins.js.bak

echo [*] Installing BetterSaves.js...
if not exist "%GAME_PATH%\www\js\plugins\" mkdir "%GAME_PATH%\www\js\plugins\"
copy /y "%~dp0BetterSaves.js" "%GAME_PATH%\www\js\plugins\BetterSaves.js" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy BetterSaves.js
  echo Make sure BetterSaves.js is in the same folder as this installer.
  pause
  exit /b 1
)
echo [OK] BetterSaves.js installed

echo [*] Registering plugin...
set "JS_FILE_PATH=%GAME_PATH:\=/%/www/js/plugins.js"
node -e "const fs = require('fs'); const filePath = '%JS_FILE_PATH%'; let content = fs.readFileSync(filePath, 'utf8'); if (content.includes('\"BetterSaves\"')) { console.log('[OK] Plugin already registered'); process.exit(0); } const lastIndex = content.lastIndexOf(']'); if (lastIndex === -1) { console.error('[ERROR] Invalid array structure'); process.exit(1); } const newPluginStr = JSON.stringify({ name: 'BetterSaves', status: true, description: 'Better saves v1.7.16', parameters: { language: 'EN', showMapId: 'false' } }, null, 4); let before = content.substring(0, lastIndex).trim(); if (before.endsWith(',')) before = before.slice(0, -1); const isArrayEmpty = before.endsWith('['); const separator = isArrayEmpty ? '\n' : ',\n'; const output = before + separator + newPluginStr + '\n];\n'; try { fs.writeFileSync(filePath, output, 'utf8'); console.log('[OK] Plugin successfully registered'); } catch (e) { console.error('[ERROR] Failed to write:', e.message); process.exit(1); }"

if errorlevel 1 (
  echo [WARNING] Automatic registration failed.
  echo.
  echo You can register the plugin manually:
  echo 1. Open %GAME_PATH%\www\js\plugins.js in Notepad
  echo 2. Add this before the last "]":
  echo ,{"name":"BetterSaves","status":true,"description":"Better saves v1.7.16","parameters":{"language":"EN","showMapId":"false"}}
  echo.
  pause
  exit /b 1
)

:done
echo.
echo ============================================
echo Done! Launch the game via Steam.
echo To change language: Options menu
echo ============================================
echo.
pause

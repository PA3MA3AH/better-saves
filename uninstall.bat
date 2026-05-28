@echo off
chcp 65001 >nul
title BetterSaves Uninstaller

echo ============================================
echo   BetterSaves - Uninstaller
echo ============================================
echo.

set GAME_PATH=
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
if not defined GAME_PATH (
    set /p GAME_PATH="Enter game path: "
)

if exist "%GAME_PATH%\www\js\plugins.js.bak" (
    copy /y "%GAME_PATH%\www\js\plugins.js.bak" "%GAME_PATH%\www\js\plugins.js" >nul
    echo [OK] plugins.js restored from backup
) else (
    echo [!] No backup found, removing plugin entry manually...
    powershell -NoProfile -Command ^
        "$f = '%GAME_PATH%\www\js\plugins.js';" ^
        "$c = Get-Content $f -Raw -Encoding UTF8;" ^
        "$c = $c -replace ',\{""name"":""BetterSaves""[^}]*\}', '';" ^
        "Set-Content $f $c -Encoding UTF8 -NoNewline;"
)

if exist "%GAME_PATH%\www\js\plugins\BetterSaves.js" (
    del "%GAME_PATH%\www\js\plugins\BetterSaves.js"
    echo [OK] BetterSaves.js removed
)

echo.
echo [OK] Uninstall complete. Your saves are NOT affected.
pause

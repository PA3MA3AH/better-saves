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
    for /f "tokens=2*" %%a in ('reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
)
if not defined GAME_PATH (
    set /p GAME_PATH="Enter game path: "
)

if exist "%GAME_PATH%\www\js\plugins.js.bak" (
    copy /y "%GAME_PATH%\www\js\plugins.js.bak" "%GAME_PATH%\www\js\plugins.js" >nul
    del "%GAME_PATH%\www\js\plugins.js.bak" >nul
    echo [OK] plugins.js restored from backup
) else (
    echo [!] No backup found, removing plugin entry manually...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$f = '%GAME_PATH%\www\js\plugins.js';" ^
        "$c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8);" ^
        "$c = $c -replace ',\s*\{[^}]*""BetterSaves""[^}]*\}', '';" ^
        "[System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8);"
    echo [OK] Plugin entry removed
)

if exist "%GAME_PATH%\www\js\plugins\BetterSaves.js" (
    del "%GAME_PATH%\www\js\plugins\BetterSaves.js" >nul
    echo [OK] BetterSaves.js removed
)

echo.
echo [OK] Uninstall complete. Your save files are NOT affected.
echo.
pause

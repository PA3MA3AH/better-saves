@echo off
chcp 65001 >nul
title BetterSaves Uninstaller

echo ============================================
echo   BetterSaves - Uninstaller
echo ============================================
echo.

set GAME_PATH=

:: --- Registry search ---
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
if not defined GAME_PATH (
    for /f "tokens=2*" %%a in ('reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
)

:: --- Common paths fallback ---
if not defined GAME_PATH (
    for %%d in (C D E F G) do (
        for %%p in (
            "%%d:\Program Files (x86)\Steam\steamapps\common\The Coffin of Andy and Leyley"
            "%%d:\Program Files\Steam\steamapps\common\The Coffin of Andy and Leyley"
            "%%d:\Steam\steamapps\common\The Coffin of Andy and Leyley"
            "%%d:\SteamLibrary\steamapps\common\The Coffin of Andy and Leyley"
        ) do (
            if exist %%p\www\js\plugins.js (
                set GAME_PATH=%%~p
                goto :check_path
            )
        )
    )
)

:check_path
:: --- Ask user if still not found ---
if not defined GAME_PATH (
    echo Game not found automatically.
    echo.
    set /p GAME_PATH="Enter full path to game folder: "
)

:: --- Validate ---
if not exist "%GAME_PATH%\www\js\plugins.js" (
    echo.
    echo [ERROR] plugins.js not found at:
    echo   %GAME_PATH%\www\js\plugins.js
    echo.
    echo Make sure the path is correct.
    echo Example: C:\Program Files (x86)\Steam\steamapps\common\The Coffin of Andy and Leyley
    echo.
    pause
    exit /b 1
)

echo [OK] Game found: %GAME_PATH%
echo.

:: --- Check write access ---
set TEST_FILE=%GAME_PATH%\www\js\.write_test
echo test > "%TEST_FILE%" 2>nul
if not exist "%TEST_FILE%" (
    echo [WARNING] No write permission. Try running as Administrator.
    echo Right-click install.bat ^> Run as administrator
    echo.
)
del "%TEST_FILE%" 2>nul

:: --- Remove BetterSaves.js ---
if exist "%GAME_PATH%\www\js\plugins\BetterSaves.js" (
    del "%GAME_PATH%\www\js\plugins\BetterSaves.js"
    if exist "%GAME_PATH%\www\js\plugins\BetterSaves.js" (
        echo [ERROR] Failed to remove BetterSaves.js - access denied
        echo Try running as Administrator.
    ) else (
        echo [OK] BetterSaves.js removed
    )
) else (
    echo [INFO] BetterSaves.js not found
)

:: --- Remove empty plugins folder ---
if exist "%GAME_PATH%\www\js\plugins\" (
    dir /b "%GAME_PATH%\www\js\plugins\" 2>nul | findstr "^" >nul
    if errorlevel 1 (
        rmdir "%GAME_PATH%\www\js\plugins\"
    )
)

:: --- Restore backup ---
if exist "%GAME_PATH%\www\js\plugins.js.bak" (
    echo [*] Restoring plugins.js from backup...
    copy /y "%GAME_PATH%\www\js\plugins.js.bak" "%GAME_PATH%\www\js\plugins.js" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to restore backup
    ) else (
        ren "%GAME_PATH%\www\js\plugins.js.bak" "plugins.js.bak.old"
        echo [OK] plugins.js restored (backup kept as plugins.js.bak.old)
    )
) else (
    :: --- Manual removal from plugins.js ---
    echo [*] No backup found, removing BetterSaves from plugins.js...
    
    set PS_FILE=%TEMP%\remove_plugin.ps1
    (
    echo $f = '%GAME_PATH:\=\\%\www\js\plugins.js'
    echo $c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8^)
    echo $c = $c -replace '\s*,?\s*\{\s*"name"\s*:\s*"BetterSaves"[^}]*\}\s*', ''
    echo $c = $c -replace ',\s*\]', ']'
    echo $c = $c -replace '\[\s*,', '['
    echo [System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8^)
    echo Write-Output 'OK'
    ) > "%PS_FILE%"

    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_FILE%" >nul 2>&1
    del "%PS_FILE%" 2>nul
    
    if errorlevel 1 (
        echo [WARNING] Could not auto-remove plugin entry
        echo.
        echo Please manually edit this file:
        echo   %GAME_PATH%\www\js\plugins.js
        echo.
        echo Find and remove the line with "BetterSaves"
    ) else (
        echo [OK] Plugin entry removed from plugins.js
    )
)

echo.
echo ============================================
echo   Uninstall complete!
echo   Your save files are NOT affected.
echo ============================================
echo.
pause

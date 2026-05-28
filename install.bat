@echo off
chcp 65001 >nul
title BetterSaves Installer

echo ============================================
echo   BetterSaves v1.1 - Installer
echo   The Coffin of Andy and Leyley
echo ============================================
echo.

:: Find game via Steam registry
set GAME_PATH=
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
if not defined GAME_PATH (
    for /f "tokens=2*" %%a in ('reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
)

:: Try common Steam paths if registry failed
if not defined GAME_PATH (
    set CANDIDATES=^
        "C:\Program Files (x86)\Steam\steamapps\common\The Coffin of Andy and Leyley" ^
        "C:\Program Files\Steam\steamapps\common\The Coffin of Andy and Leyley" ^
        "D:\Steam\steamapps\common\The Coffin of Andy and Leyley" ^
        "D:\SteamLibrary\steamapps\common\The Coffin of Andy and Leyley" ^
        "E:\Steam\steamapps\common\The Coffin of Andy and Leyley" ^
        "E:\SteamLibrary\steamapps\common\The Coffin of Andy and Leyley"
    for %%p in (%CANDIDATES%) do (
        if exist %%p\www\js\plugins.js (
            set GAME_PATH=%%~p
        )
    )
)

if not defined GAME_PATH (
    echo [!] Game not found automatically.
    echo.
    echo Please enter the full path to the game folder manually.
    echo Example: C:\Program Files (x86)\Steam\steamapps\common\The Coffin of Andy and Leyley
    echo.
    set /p GAME_PATH="Path: "
)

:: Validate
if not exist "%GAME_PATH%\www\js\plugins.js" (
    echo.
    echo [ERROR] plugins.js not found in: %GAME_PATH%
    echo Make sure the path is correct and the game is installed.
    pause
    exit /b 1
)

echo [OK] Game found: %GAME_PATH%
echo.

:: Backup plugins.js
echo [*] Creating backup of plugins.js...
copy /y "%GAME_PATH%\www\js\plugins.js" "%GAME_PATH%\www\js\plugins.js.bak" >nul
echo [OK] Backup saved as plugins.js.bak

:: Copy plugin file
echo [*] Copying BetterSaves.js...
if not exist "%GAME_PATH%\www\js\plugins\" mkdir "%GAME_PATH%\www\js\plugins\"
copy /y "%~dp0BetterSaves.js" "%GAME_PATH%\www\js\plugins\BetterSaves.js" >nul
echo [OK] BetterSaves.js copied

:: Check if already registered
findstr /c:"BetterSaves" "%GAME_PATH%\www\js\plugins.js" >nul 2>&1
if %errorlevel% == 0 (
    echo [OK] Plugin already registered in plugins.js, skipping.
    goto done
)

:: Add plugin entry to plugins.js
echo [*] Registering plugin in plugins.js...
powershell -NoProfile -Command ^
    "$f = '%GAME_PATH%\www\js\plugins.js';" ^
    "$c = Get-Content $f -Raw -Encoding UTF8;" ^
    "$entry = ',{\"name\":\"BetterSaves\",\"status\":true,\"description\":\"Better saves v1.1\",\"parameters\":{\"language\":\"RU\",\"showMapId\":\"true\"}}';" ^
    "$c = $c.TrimEnd().TrimEnd(';').TrimEnd(']') + $entry + \"`n];\`n\";" ^
    "Set-Content $f $c -Encoding UTF8 -NoNewline;"
echo [OK] Plugin registered

:done
echo.
echo ============================================
echo   Installation complete! 
echo   Launch the game via Steam as usual.
echo   Language can be changed in Options menu.
echo ============================================
echo.
pause

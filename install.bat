@echo off
chcp 65001 >nul
title BetterSaves Installer

echo ============================================
echo   BetterSaves v1.4
echo   The Coffin of Andy and Leyley
echo ============================================
echo.

:: --- Find game path via Steam registry ---
set GAME_PATH=

for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
if defined GAME_PATH goto :validate

for /f "tokens=2*" %%a in ('reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2378900" /v "InstallLocation" 2^>nul') do set GAME_PATH=%%b
if defined GAME_PATH goto :validate

:: --- Try common Steam library paths ---
for %%d in (C D E F G) do (
    for %%p in (
        "%%d:\Program Files (x86)\Steam\steamapps\common\The Coffin of Andy and Leyley"
        "%%d:\Program Files\Steam\steamapps\common\The Coffin of Andy and Leyley"
        "%%d:\Steam\steamapps\common\The Coffin of Andy and Leyley"
        "%%d:\SteamLibrary\steamapps\common\The Coffin of Andy and Leyley"
        "%%d:\Games\steamapps\common\The Coffin of Andy and Leyley"
    ) do (
        if exist %%p\www\js\plugins.js (
            set GAME_PATH=%%~p
            goto :validate
        )
    )
)

:: --- Ask user ---
echo [!] Could not find the game automatically.
echo.
echo Please enter the full path to the game folder.
echo Example: C:\Program Files (x86)\Steam\steamapps\common\The Coffin of Andy and Leyley
echo.
set /p GAME_PATH="Path: "

:validate
if not exist "%GAME_PATH%\www\js\plugins.js" (
    echo.
    echo [ERROR] Game not found at: %GAME_PATH%
    echo Make sure the game is installed and the path is correct.
    echo.
    pause
    exit /b 1
)

echo [OK] Game found: %GAME_PATH%
echo.

:: --- Backup plugins.js ---
echo [*] Backing up plugins.js...
copy /y "%GAME_PATH%\www\js\plugins.js" "%GAME_PATH%\www\js\plugins.js.bak" >nul
if errorlevel 1 (
    echo [ERROR] Failed to backup plugins.js
    pause
    exit /b 1
)
echo [OK] Backup saved: plugins.js.bak

:: --- Copy BetterSaves.js ---
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

:: --- Register plugin in plugins.js ---
findstr /c:"BetterSaves" "%GAME_PATH%\www\js\plugins.js" >nul 2>&1
if %errorlevel% == 0 (
    echo [OK] Plugin already registered in plugins.js
    goto :done
)

echo [*] Registering plugin...
set PS_SCRIPT="%TEMP%\register_plugin.ps1"
(
echo $f = '%GAME_PATH:\=\\%\www\js\plugins.js'
echo $c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8^)
echo $c = $c.TrimEnd(^).TrimEnd(']'^).TrimEnd(^).TrimEnd(';'^)
echo $entry = ', { ^"name^": ^"BetterSaves^", ^"status^": true, ^"description^": ^"Better saves v1.4^", ^"parameters^": { ^"language^": ^"EN^", ^"showMapId^": ^"true^" } }'
echo $c = $c + $entry
echo $c = $c + ^"`r`n];`r`n^"
echo [System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8^)
echo Write-Host 'Script completed successfully'
) > %PS_SCRIPT%

powershell -NoProfile -ExecutionPolicy Bypass -File %PS_SCRIPT%
if errorlevel 1 (
    echo [WARNING] Automatic registration failed.
    echo.
    echo You can register the plugin manually:
    echo 1. Open %GAME_PATH%\www\js\plugins.js in Notepad
    echo 2. Add this before the last "]":
    echo    ,{"name":"BetterSaves","status":true,"description":"Better saves v1.4","parameters":{"language":"EN","showMapId":"true"}}
    echo.
    pause
    exit /b 1
)

del %PS_SCRIPT% 2>nul
echo [OK] Plugin registered

:done
echo.
echo ============================================
echo   Done! Launch the game via Steam.
echo   To change language: Options menu
echo   To uninstall: run uninstall.bat
echo ============================================
echo.
pause

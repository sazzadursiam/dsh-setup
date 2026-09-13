@echo off
setlocal enabledelayedexpansion
title dsh + Figma - Check for updates

REM Check whether new commits have landed on the shared repo, and offer to
REM update. Built to be safe to run at login (see enable-autoupdate.bat):
REM when this checkout is already up to date it prints one line and exits,
REM so a login launch is silent. It only stops and asks when there is
REM something new.

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
cd /d "%SCRIPT_DIR%" || goto :nodir

where git >nul 2>&1
if errorlevel 1 goto :nogit
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 goto :noclone

echo.
echo   Checking for updates...

REM A fetch only refreshes origin/* - it never touches your working tree.
REM The actual pull happens in update.bat, and only after you answer Y.
git fetch --quiet
if errorlevel 1 goto :nofetch

git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>&1
if errorlevel 1 goto :noupstream

set "BEHIND=0"
for /f %%c in ('git rev-list --count HEAD..@{u} 2^>nul') do set "BEHIND=%%c"

if "%BEHIND%"=="0" (
    echo   [ OK ] Already up to date
    exit /b 0
)

echo.
echo   !BEHIND! update(s) available.
echo   The shared rules and dsh itself may have changed.
echo.
set /p "DOIT=  Update now? [y/N] "
if /i "!DOIT!"=="Y" (
    call "%SCRIPT_DIR%\update.bat"
    exit /b !errorlevel!
)
echo   [INFO] Skipped - run update.bat whenever you want.
exit /b 0

:nodir
echo   [FAIL] Cannot enter %SCRIPT_DIR%
pause
exit /b 1

:nogit
echo   [FAIL] git not found. Install it, then run again.
pause
exit /b 1

:noclone
echo   [FAIL] %SCRIPT_DIR% is not a git clone. Re-clone the repo to get updates.
pause
exit /b 1

:nofetch
echo   [WARN] Could not reach the repo to check (offline?).
echo          Nothing changed. Run update.bat when you are back online.
pause
exit /b 1

:noupstream
echo   [WARN] This clone has no upstream branch to check against.
echo          Run update.bat to pull by hand.
pause
exit /b 1

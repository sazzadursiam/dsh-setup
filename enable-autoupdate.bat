@echo off
setlocal
title dsh + Figma - Enable auto-update check

REM One command: drop a shortcut to check.bat into the Windows Startup
REM folder, so Windows checks for updates at every login. check.bat is
REM silent when there is nothing new, and asks once when there is.

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "LNK=%STARTUP%\dsh-check-updates.lnk"

echo.
echo   Adding a startup entry: %LNK%
echo.
echo   The shortcut points at check.bat in THIS folder, so it keeps working
echo   after update.bat pulls a newer check.bat.

powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut('%LNK%'); $sc.TargetPath = '%SCRIPT_DIR%\check.bat'; $sc.WorkingDirectory = '%SCRIPT_DIR%'; $sc.Save()"
if errorlevel 1 goto :failed

echo   [ OK ] Done. From now on Windows checks at login.
echo         Remove it any time: press Win+R, type shell:startup
echo         If you move this repo, run this script again from the new location.
pause
exit /b 0

:failed
echo.
echo   [FAIL] Could not create the startup entry.
echo          Do it by hand: Win+R, type shell:startup, then copy a shortcut
echo          to check.bat into that folder.
pause
exit /b 1

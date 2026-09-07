@echo off
setlocal enabledelayedexpansion
title dsh + Figma Setup

echo.
echo ============================================
echo   dsh + Figma - Setup
echo ============================================
echo.
echo This installs: Node.js, Git, dsh
echo.
echo NOTE: If Node.js or Git are installed by this script,
echo       you must CLOSE this window and RUN IT AGAIN.
echo       Windows only picks up new PATH entries in a new terminal.
echo.
pause
echo.

set NEEDS_RESTART=0

REM ---------- Node.js ----------
echo [1/3] Checking Node.js...
where node >nul 2>&1
if errorlevel 1 (
    echo       Not found. Installing...
    winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    set NEEDS_RESTART=1
) else (
    for /f "delims=" %%v in ('node -v') do echo       Found %%v
)
echo.

REM ---------- Git ----------
echo [2/3] Checking Git...
where git >nul 2>&1
if errorlevel 1 (
    echo       Not found. Installing...
    winget install --id Git.Git --accept-source-agreements --accept-package-agreements
    set NEEDS_RESTART=1
) else (
    for /f "delims=" %%v in ('git --version') do echo       Found %%v
)
echo.

if "%NEEDS_RESTART%"=="1" (
    echo ============================================
    echo   RESTART REQUIRED
    echo ============================================
    echo.
    echo Node.js and/or Git were just installed.
    echo Close this window, open a NEW Command Prompt,
    echo and run setup.bat again.
    echo.
    pause
    exit /b 0
)

REM ---------- dsh ----------
echo [3/3] Installing dsh...
echo       This takes a few minutes.
call npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
if errorlevel 1 goto :failed
echo.

echo ============================================
echo   INSTALL COMPLETE
echo ============================================
echo.
echo Manual steps left - see SETUP.md for details:
echo.
echo  1. Set your Figma token (get it from figma.com - Settings - Security):
echo        setx FIGMA_ACCESS_TOKEN "figd_your_token"
echo        setx ENABLE_MCP_APPS true
echo     Then CLOSE this window and open a new one.
echo.
echo  2. Copy the MCP config into your dsh profile:
echo        copy cordis.patch.yml "%USERPROFILE%\.dsh\profiles\web\"
echo     If you already have entries in that file, merge by hand instead.
echo.
echo  3. Run:  dsh web
echo     Open: http://127.0.0.1:3080
echo     Settings - Models - add your Anthropic API key
echo     (console.anthropic.com)
echo.
echo  4. Open Figma Desktop, press Ctrl+/ , type: import
echo     Choose "Import plugin from manifest..."
echo     File: %USERPROFILE%\.figma-console-mcp\plugin\manifest.json
echo     (The folder appears only AFTER dsh has started the MCP server once.)
echo.
echo  5. Run the "Figma Desktop Bridge" plugin in your Figma file.
echo     Wait for the green "Connected" status.
echo.
echo  6. Copy AGENTS.md into each project folder you work in.
echo.
pause
exit /b 0

:failed
echo.
echo ============================================
echo   SETUP FAILED
echo ============================================
echo.
echo The last step did not complete. Common causes:
echo.
echo  - Running in PowerShell instead of Command Prompt.
echo    Fix: press Win+R, type cmd, run setup.bat there.
echo.
echo  - No internet, or a proxy blocking npm.
echo.
echo  - Node.js or Git installed but terminal not restarted.
echo    Fix: close this window, open a new one, run again.
echo.
echo See SETUP.md troubleshooting section.
echo.
pause
exit /b 1
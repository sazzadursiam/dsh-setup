@echo off
setlocal enabledelayedexpansion
title dsh + Figma Verify

set FAIL=0

echo.
echo ============================================
echo   dsh + Figma - Verify
echo ============================================
echo.

REM ---------- Node ----------
where node >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Node.js not found
    echo          Run setup.bat, then open a NEW terminal.
    set FAIL=1
) else (
    for /f "delims=" %%v in ('node -v') do echo   [ OK ] Node.js %%v
)

REM ---------- Git ----------
where git >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Git not found - only needed for version control
) else (
    for /f "tokens=3" %%v in ('git --version') do echo   [ OK ] Git %%v
)

REM ---------- dsh ----------
where dsh >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] dsh not found
    echo          npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
    set FAIL=1
) else (
    echo   [ OK ] dsh installed
)

REM ---------- Figma token ----------
if "%FIGMA_ACCESS_TOKEN%"=="" (
    echo   [FAIL] FIGMA_ACCESS_TOKEN not set in this terminal
    echo          Run:  setx FIGMA_ACCESS_TOKEN "figd_..."
    echo          Then CLOSE this window and open a NEW one, then re-run this.
    echo          (setx only affects NEW terminals - same-window rechecks still fail.)
    set FAIL=1
) else (
    echo   [ OK ] FIGMA_ACCESS_TOKEN is set
    echo %FIGMA_ACCESS_TOKEN% | findstr /b "figd_" >nul
    if errorlevel 1 (
        echo   [WARN] Token does not start with figd_ - check you copied the right value
    )
)

REM ---------- ENABLE_MCP_APPS ----------
if "%ENABLE_MCP_APPS%"=="" (
    echo   [WARN] ENABLE_MCP_APPS not set
    echo          setx ENABLE_MCP_APPS true
) else (
    echo   [ OK ] ENABLE_MCP_APPS = %ENABLE_MCP_APPS%
)

REM ---------- MCP config ----------
set CFG=%USERPROFILE%\.dsh\profiles\web\cordis.patch.yml
if not exist "%CFG%" (
    echo   [FAIL] cordis.patch.yml not found
    echo          Run dsh web once to create the profile, then copy the config.
    set FAIL=1
) else (
    findstr /c:"serverName: figma" "%CFG%" >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] cordis.patch.yml has no figma entry
        echo          copy cordis.patch.yml "%%USERPROFILE%%\.dsh\profiles\web\"
        set FAIL=1
    ) else (
        echo   [ OK ] MCP config has the figma entry
    )
)

REM ---------- Anthropic key ----------
set CRED=%USERPROFILE%\.dsh\.credentials.yaml
if not exist "%CRED%" (
    echo   [WARN] No credentials file yet
    echo          Add your API key in dsh: Settings ^> Models
) else (
    echo   [ OK ] Credentials file exists
)

REM ---------- Bridge plugin ----------
set PLUG=%USERPROFILE%\.figma-console-mcp\plugin\manifest.json
if not exist "%PLUG%" (
    echo   [FAIL] Bridge plugin files not generated yet
    echo          Start dsh web and open a session once, then re-run this.
    set FAIL=1
) else (
    echo   [ OK ] Bridge plugin files present
    echo          Import in Figma Desktop: Ctrl+/ then type "import"
    echo          %PLUG%
)

REM ---------- dsh running? ----------
netstat -ano | findstr ":3080" >nul 2>&1
if errorlevel 1 (
    echo   [INFO] dsh does not appear to be running - start it with: dsh web
) else (
    echo   [ OK ] Something is listening on port 3080
)

echo.
echo ============================================
if "%FAIL%"=="1" (
    echo   SOME CHECKS FAILED - see the notes above
    echo   Details in SETUP.md
) else (
    echo   ALL CHECKS PASSED
    echo.
    echo   Last step is manual: open Figma Desktop, run the
    echo   "Figma Desktop Bridge" plugin, and look for the
    echo   green "Connected" status.
    echo.
    echo   Then in a dsh session, run:  figma_get_status
)
echo ============================================
echo.
pause
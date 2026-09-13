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
REM Pinned, not "latest": the newest release on the registry is not always one
REM this setup can use. DSH_VERSION records the version we install; see the
REM blocked list in plugins\team-updater\cordis.patch.yml for what is being
REM avoided and why. Empty or missing file means "whatever is latest".
set "DSH_PIN="
if exist "%~dp0DSH_VERSION" (
    for /f "usebackq delims=" %%v in ("%~dp0DSH_VERSION") do if not defined DSH_PIN set "DSH_PIN=%%v"
)
set "DSH_SPEC=@deepseek-ai/dsh"
if defined DSH_PIN set "DSH_SPEC=@deepseek-ai/dsh@%DSH_PIN%"
echo [3/3] Installing dsh %DSH_PIN%...
echo       This takes a few minutes.
call npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs %DSH_SPEC%
if errorlevel 1 goto :failed
echo.

REM ---------- in-GUI update button ----------
REM The profile only exists once dsh has been started at least once, so on a
REM fresh machine this is a hint rather than a step. `dsh plugin ... add`
REM appends the bundle by itself, because the package declares dsh.bundle.patch.
echo [+] Adding the in-app update button...
set "DSH_PROFILE_DIR=%DSH_HOME%"
if not defined DSH_PROFILE_DIR set "DSH_PROFILE_DIR=%USERPROFILE%\.dsh"
if exist "%DSH_PROFILE_DIR%\profiles\web" (
    call dsh plugin --profile web add "file:%~dp0plugins\team-updater" >nul 2>&1
    if errorlevel 1 (
        echo   [WARN] Could not add it - run this by hand:
        echo          dsh plugin --profile web add "file:%~dp0plugins\team-updater"
    ) else (
        echo   [ OK ] Update button added - Settings ^> General, after a restart
    )
) else (
    echo   [WARN] No web profile yet - run "dsh web" once, then re-run this script
)
echo.

REM ---------- agent rules ----------
REM One file per machine at %USERPROFILE%\.dsh\AGENTS.md, which dsh loads into
REM every session of every project. Asks once which roles this machine works in.
echo [+] Setting up the shared agent rules...
if exist "%~dp0agents.bat" (
    call "%~dp0agents.bat"
    if errorlevel 1 echo   [WARN] Could not write the agent rules - run agents.bat by hand
) else (
    echo   [WARN] agents.bat is missing from this checkout - skipping
)
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
echo  The shared agent rules are already installed at %USERPROFILE%\.dsh\AGENTS.md
echo  and apply to every project. Per-project rules go in that project's own
echo  AGENTS.md - see templates\project.example.md.
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

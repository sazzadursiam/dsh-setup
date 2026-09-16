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
REM The packages whose install scripts npm may run. It belongs to the pinned
REM version - a new dsh can bring a new native dependency - so it lives in
REM DSH_ALLOW_SCRIPTS next to DSH_VERSION, read by every install path.
set "DSH_ALLOW="
if exist "%~dp0DSH_ALLOW_SCRIPTS" (
    for /f "usebackq tokens=1" %%v in ("%~dp0DSH_ALLOW_SCRIPTS") do if not defined DSH_ALLOW set "DSH_ALLOW=%%v"
)
if not defined DSH_ALLOW (
    echo DSH_ALLOW_SCRIPTS is missing or empty - this checkout is incomplete.
    goto :failed
)
echo [3/3] Installing dsh %DSH_PIN%...
echo       This takes a few minutes.
call npm install -g --allow-scripts=%DSH_ALLOW% %DSH_SPEC%
if errorlevel 1 goto :failed
echo.

REM ---------- dsh plugins (update button, Figma MCP) ----------
REM The profile only exists once dsh has been started at least once, so on a
REM fresh machine this is a hint rather than a step. `dsh plugin ... add`
REM appends each bundle by itself, because the packages declare dsh.bundle.patch.
echo [+] Adding dsh plugins (update button, Figma MCP)...
set "DSH_PROFILE_DIR=%DSH_HOME%"
if not defined DSH_PROFILE_DIR set "DSH_PROFILE_DIR=%USERPROFILE%\.dsh"
set "REPO_DIR=%~dp0"
set "PLUGIN_LOG=%TEMP%\dsh-setup-plugin-add.log"
REM dsh runs pnpm through a shell on Windows without quoting its arguments, so
REM a checkout path with a space reaches pnpm cut in two ("X:/My" not found).
REM Quotes carried inside the argument survive that join; """...""" gives node
REM the literal quotes while keeping the path inside cmd's own quoting, so a
REM "(" or ")" in it cannot end the block below. Used only when the path has a
REM space, so the plain form keeps working if dsh stops using a shell.
set "UPDATER_SPEC=file:%REPO_DIR%plugins\team-updater"
set "UPDATER_ARG="%UPDATER_SPEC%""
if not "%UPDATER_SPEC: =%"=="%UPDATER_SPEC%" set "UPDATER_ARG="""%UPDATER_SPEC%""""
set "FIGMA_SPEC=file:%REPO_DIR%plugins\figma-bridge"
set "FIGMA_ARG="%FIGMA_SPEC%""
if not "%FIGMA_SPEC: =%"=="%FIGMA_SPEC%" set "FIGMA_ARG="""%FIGMA_SPEC%""""
REM pnpm itself cannot install from a path with brackets in it - it uses them in
REM lockfile keys and fails with "Mismatch parenthesis" - so say so up front.
set "PLUGIN_BRACKETS="
if not "%REPO_DIR:(=%"=="%REPO_DIR%" set "PLUGIN_BRACKETS=1"
if not "%REPO_DIR:)=%"=="%REPO_DIR%" set "PLUGIN_BRACKETS=1"
if defined PLUGIN_BRACKETS (
    echo   [WARN] Skipped: pnpm cannot install a plugin from a folder whose path
    echo          contains a bracket. Move this checkout to a path without ^( or ^)
    echo          and run this again.
) else if exist "%DSH_PROFILE_DIR%\profiles\web" (
    REM `dsh plugin` runs whatever pnpm is on PATH and does not ship one, so a
    REM machine with only Node and npm fails with "'pnpm' is not recognized".
    REM Major 12 is what this was tested with; its install script swaps in the
    REM native binary, which npm 11 only runs when allowed.
    where pnpm >nul 2>&1
    if errorlevel 1 (
        echo          pnpm not found - installing it, dsh plugins need it...
        call npm install -g --allow-scripts=pnpm pnpm@12
    )
    REM A hand-copied profile from before figma-bridge existed would otherwise
    REM end up with two "serverName: figma" rows once the plugin is added.
    where node >nul 2>&1
    if not errorlevel 1 node "%REPO_DIR%plugins\figma-bridge\lib\migrate.js"
    call dsh plugin --profile web add %UPDATER_ARG% > "%PLUGIN_LOG%" 2>&1
    if errorlevel 1 (
        echo   [WARN] Could not add team-updater. pnpm said:
        type "%PLUGIN_LOG%"
        echo          Run this by hand once the cause is fixed:
        echo          dsh plugin --profile web add %UPDATER_ARG%
    ) else (
        echo   [ OK ] team-updater added
    )
    call dsh plugin --profile web add %FIGMA_ARG% > "%PLUGIN_LOG%" 2>&1
    if errorlevel 1 (
        echo   [WARN] Could not add figma-bridge. pnpm said:
        type "%PLUGIN_LOG%"
        echo          Run this by hand once the cause is fixed:
        echo          dsh plugin --profile web add %FIGMA_ARG%
    ) else (
        echo   [ OK ] figma-bridge added
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
echo  2. Run:  dsh web
echo     Open: http://127.0.0.1:3080
echo     Settings - Models - add your Anthropic API key
echo     (console.anthropic.com)
echo.
echo  3. Open Figma Desktop, press Ctrl+/ , type: import
echo     Choose "Import plugin from manifest..."
echo     File: %USERPROFILE%\.figma-console-mcp\plugin\manifest.json
echo     (The folder appears only AFTER dsh has started the MCP server once.)
echo.
echo  4. Run the "Figma Desktop Bridge" plugin in your Figma file.
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

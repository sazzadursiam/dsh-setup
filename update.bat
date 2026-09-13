@echo off
setlocal enabledelayedexpansion
title dsh + Figma Update

REM Update an existing dsh + Figma setup on Windows.
REM
REM   update.bat                     pull, update dsh, rewrite the agent rules
REM   update.bat --skip-dsh          pull only, leave the npm package alone
REM   update.bat --role=figma        also change which role blocks this machine gets
REM
REM Nothing here touches your projects. The shared agent rules live in one file
REM per machine, %USERPROFILE%\.dsh\AGENTS.md, which dsh loads into every session
REM automatically - so there are no per-project copies to fall behind.

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
cd /d "%SCRIPT_DIR%" || goto :nodir

REM Parsed from %* as one string: cmd.exe splits arguments on "=" as well as
REM spaces, so "--role=figma" would not survive a shift-based loop.
set SKIP_DSH=0
set "ROLE_ARG="
set "ARGS=%*"
if defined ARGS (
    if not "!ARGS!"=="!ARGS:--skip-dsh=!" set SKIP_DSH=1
    if not "!ARGS!"=="!ARGS:--role==!" (
        REM The search term cannot contain "=", so the match stops at "--role"
        REM and leaves the "=" on the front of what remains.
        set "TAIL=!ARGS:*--role=!"
        if "!TAIL:~0,1!"=="=" set "TAIL=!TAIL:~1!"
        for /f "tokens=1 delims= " %%x in ("!TAIL!") do set "ROLE_ARG=--role=%%x"
    )
)

echo.
echo ============================================
echo   dsh + Figma - Update
echo ============================================
echo.

REM ---------- 1. this repo ----------
echo [1/3] Updating this repo...
where git >nul 2>&1
if errorlevel 1 goto :nogit
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 goto :noclone

for /f "delims=" %%h in ('git rev-parse HEAD 2^>nul') do set "OLD_HEAD=%%h"

set "DIRTY="
for /f "delims=" %%s in ('git status --porcelain 2^>nul') do set "DIRTY=1"
if defined DIRTY (
    echo   [WARN] You have local changes - not pulling, so nothing of yours is lost.
    echo          Commit or stash them, then run this again:
    echo            git stash ^&^& update.bat ^&^& git stash pop
) else (
    git pull --ff-only
    if errorlevel 1 goto :pullfailed
    for /f "delims=" %%h in ('git rev-parse HEAD 2^>nul') do set "NEW_HEAD=%%h"
    if "!OLD_HEAD!"=="!NEW_HEAD!" (
        echo   [ OK ] Already up to date
    ) else (
        echo   [ OK ] Updated
        echo.
        echo   What changed:
        for /f "delims=" %%l in ('git log --oneline --no-decorate !OLD_HEAD!..!NEW_HEAD! 2^>nul') do echo     %%l
        echo.
        echo          Full notes in CHANGELOG.md
    )
)
echo.

REM ---------- 2. dsh itself ----------
echo [2/3] Updating dsh...
if "%SKIP_DSH%"=="1" (
    echo   [INFO] Skipped ^(--skip-dsh^)
) else (
    where npm >nul 2>&1
    if errorlevel 1 (
        echo   [WARN] npm not found - skipping
    ) else (
        REM Pinned, not "latest": the newest release is not always one this
        REM setup can use, and an explicit version also moves a machine back
        REM down if it already took a bad one. See the blocked list in
        REM plugins\team-updater\cordis.patch.yml for what is avoided and why.
        set "DSH_PIN="
        if exist "%SCRIPT_DIR%\DSH_VERSION" (
            for /f "usebackq delims=" %%v in ("%SCRIPT_DIR%\DSH_VERSION") do if not defined DSH_PIN set "DSH_PIN=%%v"
        )
        set "DSH_SPEC=@deepseek-ai/dsh"
        if defined DSH_PIN set "DSH_SPEC=@deepseek-ai/dsh@!DSH_PIN!"
        echo        Installing !DSH_PIN!. This takes a few minutes.
        REM Not `npm update -g`: that does not re-apply the allowlist, leaving
        REM the native modules unbuilt. See SETUP.md, Part 9.
        call npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs !DSH_SPEC!
        if errorlevel 1 (
            echo   [WARN] dsh update failed - see the npm output above
        ) else (
            echo   [ OK ] dsh updated
        )
    )
)
echo.

REM ---------- the in-GUI update button ----------
REM Re-run on every update so an existing install picks the button up, and so
REM the spec follows this checkout if it was moved. Adding it twice is a no-op.
echo [+] Checking the in-app update button...
set "DSH_PROFILE_DIR=%DSH_HOME%"
if not defined DSH_PROFILE_DIR set "DSH_PROFILE_DIR=%USERPROFILE%\.dsh"
if exist "%DSH_PROFILE_DIR%\profiles\web" (
    call dsh plugin --profile web add "file:%SCRIPT_DIR%\plugins\team-updater" >nul 2>&1
    if errorlevel 1 (
        echo   [WARN] Could not add it - run this by hand:
        echo          dsh plugin --profile web add "file:%SCRIPT_DIR%\plugins\team-updater"
    ) else (
        echo   [ OK ] Update button present - Settings ^> General
    )
) else (
    echo   [WARN] No web profile yet - run "dsh web" once, then re-run this script
)
echo.

REM ---------- 3. the shared agent rules ----------
echo [3/3] Rewriting the shared agent rules...
if not exist "%SCRIPT_DIR%\agents.bat" (
    echo   [WARN] agents.bat is missing from this checkout - skipping
) else (
    REM agents.bat reuses the roles already recorded in the generated file, so
    REM this is silent on every run after the first.
    call "%SCRIPT_DIR%\agents.bat" !ROLE_ARG!
    if errorlevel 1 echo   [WARN] Could not write the agent rules - see above
)

echo.
echo ============================================
echo   Done. Two things this cannot do for you:
echo   - Restart your sessions. Changed rules only reach a session
echo     started afterwards - there is no file watcher.
echo   - Update %%USERPROFILE%%\.dsh\settings.yaml. Model choice, reasoning
echo     effort and API keys are per-machine and live outside this repo.
echo.
echo   Project-specific rules live in each project's own AGENTS.md and are
echo   yours to maintain - see templates\project.example.md.
echo ============================================
echo.
pause
exit /b 0

:nodir
echo   [FAIL] Cannot enter %SCRIPT_DIR%
pause
exit /b 1

:nogit
echo.
echo   [FAIL] git not found. Install it, then run this again.
pause
exit /b 1

:noclone
echo.
echo   [FAIL] %SCRIPT_DIR% is not a git clone.
echo          Re-clone the repo to get updates.
pause
exit /b 1

:pullfailed
echo.
echo   [FAIL] git pull failed. Resolve it by hand, then re-run.
pause
exit /b 1

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
set AFTER_PULL=0
set "ROLE_ARG="
set "ARGS=%*"
if defined ARGS (
    if not "!ARGS!"=="!ARGS:--skip-dsh=!" set SKIP_DSH=1
    if not "!ARGS!"=="!ARGS:--after-pull=!" set AFTER_PULL=1
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
if "%AFTER_PULL%"=="1" (
    echo   [ OK ] Pulled - now running the updated copy of this script
) else (
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
            REM The pull may have just rewritten this file, and cmd reads a batch
            REM file from disk as it runs, so carrying on would resume the new
            REM file at this one's byte offset. This block is already parsed, so
            REM hand over to the new copy from here and never read this file again.
            call "%~f0" --after-pull %*
            exit /b !errorlevel!
        )
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
set "UPDATER_SPEC=file:%SCRIPT_DIR%\plugins\team-updater"
set "UPDATER_ARG="%UPDATER_SPEC%""
REM dsh runs pnpm through a shell on Windows without quoting its arguments, so
REM a checkout path with a space reaches pnpm cut in two ("X:/My" not found).
REM Quotes carried inside the argument survive that join; """...""" gives node
REM the literal quotes while keeping the path inside cmd's own quoting, so a
REM "(" or ")" in it cannot end the block below. Used only when the path has a
REM space, so the plain form keeps working if dsh stops using a shell.
if not "%UPDATER_SPEC: =%"=="%UPDATER_SPEC%" set "UPDATER_ARG="""%UPDATER_SPEC%""""
set "UPDATER_LOG=%TEMP%\dsh-setup-plugin-add.log"
REM pnpm itself cannot install from a path with brackets in it - it uses them in
REM lockfile keys and fails with "Mismatch parenthesis" - so say so up front.
set "UPDATER_BRACKETS="
if not "%UPDATER_SPEC:(=%"=="%UPDATER_SPEC%" set "UPDATER_BRACKETS=1"
if not "%UPDATER_SPEC:)=%"=="%UPDATER_SPEC%" set "UPDATER_BRACKETS=1"
REM `dsh plugin` runs whatever pnpm is on PATH and does not ship one, so a
REM machine with only Node and npm fails with "'pnpm' is not recognized".
REM Major 12 is what this was tested with; its install script swaps in the
REM native binary, which npm 11 only runs when allowed.
if defined UPDATER_BRACKETS (
    echo   [WARN] Skipped: pnpm cannot install a plugin from a folder whose path
    echo          contains a bracket. Move this checkout to a path without ^( or ^)
    echo          and run this again.
) else if exist "%DSH_PROFILE_DIR%\profiles\web" (
    where pnpm >nul 2>&1
    if errorlevel 1 (
        echo          pnpm not found - installing it, dsh plugins need it...
        call npm install -g --allow-scripts=pnpm pnpm@12
    )
    call dsh plugin --profile web add %UPDATER_ARG% > "%UPDATER_LOG%" 2>&1
    if errorlevel 1 (
        echo   [WARN] Could not add it. pnpm said:
        type "%UPDATER_LOG%"
        echo          Run this by hand once the cause is fixed:
        echo          dsh plugin --profile web add %UPDATER_ARG%
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
    REM agents.bat reuses the roles recorded in the generated file. --no-ask
    REM keeps it silent even with none recorded: roles are optional, so an
    REM update writes the core rules and says how to add roles instead.
    call "%SCRIPT_DIR%\agents.bat" --no-ask !ROLE_ARG!
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

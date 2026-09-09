@echo off
setlocal enabledelayedexpansion
title dsh + Figma Update

REM Update an existing dsh + Figma setup on Windows.
REM
REM   update.bat                          pull + update dsh
REM   update.bat C:\projects\site ...     also check those projects' AGENTS.md
REM   update.bat --skip-dsh               pull only, leave the npm package alone
REM
REM Project paths can also be listed one per line in projects.txt next to this
REM script (git-ignored), so plain `update.bat` checks them every time.

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
cd /d "%SCRIPT_DIR%" || goto :nodir

set SKIP_DSH=0
set PROJECTS=
:parseargs
if "%~1"=="" goto :parsed
if /i "%~1"=="--skip-dsh" (set SKIP_DSH=1) else (set "PROJECTS=!PROJECTS! "%~1"")
shift
goto :parseargs
:parsed

if not defined PROJECTS if exist "%SCRIPT_DIR%\projects.txt" (
    for /f "usebackq eol=# delims=" %%p in ("%SCRIPT_DIR%\projects.txt") do (
        if not "%%p"=="" set "PROJECTS=!PROJECTS! "%%p""
    )
)

set "TPL=%SCRIPT_DIR%\templates\AGENTS.md"
set "OLD_TPL="
for /f "tokens=3" %%v in ('findstr /c:"dsh-setup-template-version:" "%TPL%" 2^>nul') do set "OLD_TPL=%%v"

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
        echo        This takes a few minutes.
        REM Not `npm update -g`: that does not re-apply the allowlist, leaving
        REM the native modules unbuilt. See SETUP.md, Part 9.
        call npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
        if errorlevel 1 (
            echo   [WARN] dsh update failed - see the npm output above
        ) else (
            echo   [ OK ] dsh updated
        )
    )
)
echo.

REM ---------- 3. project AGENTS.md copies ----------
echo [3/3] Checking project AGENTS.md copies...
set "NEW_TPL="
for /f "tokens=3" %%v in ('findstr /c:"dsh-setup-template-version:" "%TPL%" 2^>nul') do set "NEW_TPL=%%v"

if not defined PROJECTS (
    echo   [INFO] No projects given - pass paths, or list them in projects.txt
    echo            update.bat C:\Users\me\projects\my-site
    if not "!OLD_TPL!"=="!NEW_TPL!" (
        echo   [WARN] The template moved v!OLD_TPL! -^> v!NEW_TPL!, so your copies are now behind.
    )
) else (
    set STALE=0
    for %%p in (!PROJECTS!) do (
        set "P=%%~p"
        if not exist "!P!\" (
            echo   [WARN] !P! - not a directory
        ) else if not exist "!P!\AGENTS.md" (
            echo   [WARN] !P! - no AGENTS.md
            echo          copy "%TPL%" "!P!\"
            set /a STALE+=1
        ) else (
            set "V="
            for /f "tokens=3" %%w in ('findstr /c:"dsh-setup-template-version:" "!P!\AGENTS.md" 2^>nul') do set "V=%%w"
            if "!V!"=="!NEW_TPL!" (
                echo   [ OK ] !P! ^(v!V!^)
            ) else (
                if "!V!"=="" (set "SHOWV=unstamped") else (set "SHOWV=v!V!")
                echo   [WARN] !P! - !SHOWV! vs template v!NEW_TPL!
                echo          fc "!P!\AGENTS.md" "%TPL%"
                set /a STALE+=1
            )
        )
    )
    if !STALE! gtr 0 (
        echo.
        echo   !STALE! project^(s^) need attention.
        echo   Copy the changed sections across by hand - do NOT overwrite the
        echo   whole file, or you lose everything under "## Project specifics".
    )
)

echo.
echo ============================================
echo   Done. Two things this cannot do for you:
echo   - Restart your sessions. Changed AGENTS.md rules only reach
echo     a session started afterwards.
echo   - Update %%USERPROFILE%%\.dsh\settings.yaml. Model choice, reasoning
echo     effort and API keys are per-machine and live outside this repo.
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

@echo off
setlocal enabledelayedexpansion

REM Write the shared agent rules to %USERPROFILE%\.dsh\AGENTS.md.
REM
REM   agents.bat                              regenerate using the remembered settings
REM   agents.bat --role=figma,visual-assets   set the roles for this machine
REM   agents.bat --role=none                  core rules only, no role block
REM   agents.bat --lang=Bengali               reply language (default: English)
REM   agents.bat --show                       print the target path and current settings
REM
REM dsh loads %DSH_HOME%\AGENTS.md (default %USERPROFILE%\.dsh\AGENTS.md) into
REM every session of every project, before any project's own AGENTS.md. So the
REM shared rules live there once per machine instead of being copied into each
REM project, where copies drift and go stale.
REM
REM Which roles apply is a property of the person at this machine, not of the
REM repo, so it is asked once and remembered in the generated file's first line.
REM
REM Project-specific rules belong in that project's own AGENTS.md, which this
REM script never touches. See templates\project.example.md.

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "TPL=%SCRIPT_DIR%\templates"
set "ROLES_DIR=%TPL%\roles"
set "INDEX=%ROLES_DIR%\index.txt"

if not exist "%TPL%\core.md" (
    echo   [FAIL] Missing %TPL%\core.md - is this a complete checkout?
    exit /b 1
)
if not exist "%INDEX%" (
    echo   [FAIL] Missing %INDEX% - is this a complete checkout?
    exit /b 1
)

set "VERSION=unknown"
if exist "%SCRIPT_DIR%\VERSION" (
    for /f "usebackq delims=" %%v in ("%SCRIPT_DIR%\VERSION") do if not defined VERSION_SET (
        set "VERSION=%%v" & set VERSION_SET=1
    )
)

set "DSH_DIR=%DSH_HOME%"
if not defined DSH_DIR set "DSH_DIR=%USERPROFILE%\.dsh"
set "TARGET=%DSH_DIR%\AGENTS.md"

REM ---------- available roles ----------
set N=0
for /f "usebackq eol=# tokens=1,* delims=|" %%a in ("%INDEX%") do (
    if not "%%a"=="" (
        if exist "%ROLES_DIR%\%%a.md" (
            set /a N+=1
            set "SLUG_!N!=%%a"
            set "DESC_!N!=%%b"
        ) else (
            echo   [WARN] index.txt lists "%%a" but %%a.md is missing - skipping
        )
    )
)
if %N%==0 (
    echo   [FAIL] No usable roles found in %INDEX%
    exit /b 1
)
set "ALL="
for /l %%i in (1,1,%N%) do (
    if defined ALL (set "ALL=!ALL!,!SLUG_%%i!") else (set "ALL=!SLUG_%%i!")
)

REM ---------- arguments ----------
REM Parsed from %* as one string, not with shift. cmd.exe treats "=" and ","
REM as argument delimiters, so "--role=figma,visual-assets" would arrive split
REM into three separate %1..%3 tokens.
set "REQUESTED="
set HAVE_REQUEST=0
set "LANG_ARG="
set HAVE_LANG=0
set SHOW=0
set "ARGS=%*"

REM Substring tests, not `echo !VAR! | findstr`: piping a variable that holds a
REM "|" - as the generated stamp line does - breaks the pipe.
if defined ARGS (
    if not "!ARGS!"=="!ARGS:--help=!" goto :help
    if not "!ARGS!"=="!ARGS:-h=!"     goto :help

    if not "!ARGS!"=="!ARGS:--show=!" set SHOW=1

    if not "!ARGS!"=="!ARGS:--role==!" (
        set HAVE_REQUEST=1
        REM The search term cannot include the "=" - that character separates
        REM search from replacement - so the match stops at "--role" and the
        REM "=" is left on the front of what remains.
        set "TAIL=!ARGS:*--role=!"
        for /f "tokens=1 delims= " %%x in ("!TAIL!") do set "REQUESTED=%%x"
        if "!REQUESTED:~0,1!"=="=" set "REQUESTED=!REQUESTED:~1!"
    )

    if not "!ARGS!"=="!ARGS:--lang==!" (
        set HAVE_LANG=1
        REM A language may contain spaces, so this takes the rest of the line
        REM rather than one token. Trimming and validation happen below, outside
        REM this block - a `goto` in here would jump out of the parentheses.
        set "LTAIL=!ARGS:*--lang=!"
        if "!LTAIL:~0,1!"=="=" set "LTAIL=!LTAIL:~1!"
        set "LANG_ARG=!LTAIL!"
    )

    if "!SHOW!"=="0" if "!HAVE_REQUEST!"=="0" if "!HAVE_LANG!"=="0" (
        echo   [FAIL] Unknown argument: !ARGS!   ^(try --help^)
        exit /b 1
    )
)
:parsed

REM ---------- tidy up --lang ----------
:trimlang
if "%HAVE_LANG%"=="0" goto :langdone
if "!LANG_ARG:~-1!"==" " (
    set "LANG_ARG=!LANG_ARG:~0,-1!"
    goto :trimlang
)
if "!LANG_ARG!"=="" (
    echo   [FAIL] --lang needs a value, for example: agents.bat --lang=Bengali
    exit /b 1
)
REM --lang takes the rest of the line, so it has to come last.
if not "!LANG_ARG!"=="!LANG_ARG:--=!" (
    echo   [FAIL] --lang must be the last option - it takes the rest of the line.
    echo          Got: !LANG_ARG!
    exit /b 1
)
REM The stamp line is parsed on these, so a language cannot contain them.
if not "!LANG_ARG!"=="!LANG_ARG:^|=!" (
    echo   [FAIL] --lang cannot contain "^|"
    exit /b 1
)
:langdone

REM ---------- read the remembered roles out of the generated file ----------
REM The stamp is how roles are remembered, so no extra state file is added to
REM .dsh - a directory that otherwise holds credentials.
set "FIRST="
set "OURS=0"
set "REMEMBERED="
if exist "%TARGET%" (
    set /p FIRST=<"%TARGET%"
    if not "!FIRST!"=="!FIRST:dsh-setup:=!" (
        set "OURS=1"
        set "R=!FIRST:*roles:=!"
        set "R=!R: -->=!"
        if "!R:~0,1!"==" " set "R=!R:~1!"
        set "REMEMBERED=!R!"
        set "STAMPED=!FIRST:*dsh-setup: =!"
        for /f "tokens=1 delims= " %%v in ("!STAMPED!") do set "FILE_VER=%%v"
        REM lang sits between the version and roles: "... | lang: X | roles: ..."
        set "LR=!FIRST:*lang: =!"
        for /f "tokens=1 delims=|" %%l in ("!LR!") do set "REM_LANG=%%l"
    )
)
:trimremlang
if not defined REM_LANG goto :remlangdone
if "!REM_LANG:~-1!"==" " (
    set "REM_LANG=!REM_LANG:~0,-1!"
    goto :trimremlang
)
:remlangdone

if "%SHOW%"=="1" (
    echo.
    echo   target : %TARGET%
    if exist "%TARGET%" (
        if "%OURS%"=="0" (
            echo   roles  : unknown - this file was not written by agents.bat
        ) else (
            if "!REMEMBERED!"=="" (set "SHOWR=none - core only") else (set "SHOWR=!REMEMBERED!")
            echo   roles  : !SHOWR!
            echo   lang   : !REM_LANG!
            REM Never echo !FIRST! raw: it opens with "<!--", which cmd reads as
            REM a redirection, and it holds a "|".
            echo   written by : dsh-setup !FILE_VER!
        )
        for %%f in ("%TARGET%") do echo   size   : %%~zf bytes
    ) else (
        echo   roles  : - not written yet
    )
    echo   offered: %ALL%
    if exist "%SCRIPT_DIR%\local.md" (
        for %%f in ("%SCRIPT_DIR%\local.md") do echo   local  : local.md is appended ^(%%~zf bytes^)
    )
    echo.
    exit /b 0
)

REM ---------- decide the language ----------
if "%HAVE_LANG%"=="0" (
    if defined REM_LANG (
        set "LANG_ARG=!REM_LANG!"
    ) else (
        set "LANG_ARG=English"
    )
)

REM ---------- decide the roles ----------
if "%HAVE_REQUEST%"=="0" (
    if "%OURS%"=="1" (
        set "REQUESTED=!REMEMBERED!"
        if "!REQUESTED!"=="" (
            echo   [INFO] Using the roles already set on this machine: none
        ) else (
            echo   [INFO] Using the roles already set on this machine: !REQUESTED!
        )
    ) else (
        echo.
        echo   Which kinds of work happen on this machine?
        echo   This picks which rule blocks get loaded. Nothing else changes.
        echo.
        for /l %%i in (1,1,%N%) do echo     %%i^) !SLUG_%%i!  -  !DESC_%%i!
        echo.
        set "PICKED="
        set /p "PICKED=  Numbers, separated by spaces (Enter for none): "
        set "SEL="
        for %%n in (!PICKED!) do (
            set "OK="
            for /l %%i in (1,1,%N%) do if "%%n"=="%%i" set "OK=!SLUG_%%i!"
            if defined OK (
                if defined SEL (set "SEL=!SEL!,!OK!") else (set "SEL=!OK!")
            ) else (
                echo   [WARN] Ignoring "%%n" - not one of the numbers above
            )
        )
        set "REQUESTED=!SEL!"
        echo.
    )
)

if /i "%REQUESTED%"=="none" set "REQUESTED="

REM ---------- validate and de-duplicate ----------
set "CHOSEN="
set CN=0
REM Record a bad role and report it after the loop: `exit /b` from inside a FOR
REM body runs, but its exit code does not survive back to the caller.
set "BADROLE="
for %%r in (%REQUESTED%) do (
    set "RR=%%r"
    set "VALID="
    for /l %%i in (1,1,%N%) do if /i "!RR!"=="!SLUG_%%i!" set "VALID=!SLUG_%%i!"
    if not defined VALID (
        set "BADROLE=!RR!"
    ) else (
        set "DUP="
        for /l %%j in (1,1,!CN!) do if /i "!VALID!"=="!CHOSE_%%j!" set "DUP=1"
        if not defined DUP (
            set /a CN+=1
            set "CHOSE_!CN!=!VALID!"
            if defined CHOSEN (set "CHOSEN=!CHOSEN!,!VALID!") else (set "CHOSEN=!VALID!")
        )
    )
)
if defined BADROLE (
    echo.
    echo   [FAIL] Unknown role: %BADROLE%
    echo          Available: %ALL%
    exit /b 1
)

REM ---------- protect anything we did not write ----------
if not exist "%DSH_DIR%" mkdir "%DSH_DIR%" 2>nul
if not exist "%DSH_DIR%" (
    echo   [FAIL] Cannot create %DSH_DIR%
    exit /b 1
)
if exist "%TARGET%" if "%OURS%"=="0" (
    copy /y "%TARGET%" "%TARGET%.bak" >nul
    echo   [WARN] %TARGET% was not written by this script - saved a copy as AGENTS.md.bak
)

REM ---------- assemble ----------
set "TMPF=%TEMP%\dsh-agents-%RANDOM%%RANDOM%.md"
REM Delayed expansion is off for these four lines on purpose: with it on there
REM is no reliable way to echo the "!" in "<!--" - it eats the rest of the line.
REM Only %VAR% expansion is needed here, so the narrow scope costs nothing.
setlocal disabledelayedexpansion
> "%TMPF%" echo ^<!-- dsh-setup: v%VERSION% ^| lang: %LANG_ARG% ^| roles: %CHOSEN% --^>
>>"%TMPF%" echo ^<!-- Generated by dsh-setup. Edits here are overwritten on the next
>>"%TMPF%" echo      update. Project rules go in that project's own AGENTS.md; machine-
>>"%TMPF%" echo      specific rules go in local.md in your dsh-setup checkout. --^>
>>"%TMPF%" echo.
REM The scripts own the document skeleton so the language rule can be a setting;
REM core.md picks up from "Be direct" inside this same section.
>>"%TMPF%" echo # Agent Instructions
>>"%TMPF%" echo.
>>"%TMPF%" echo Rules for any agent working with me, on any project on this machine.
>>"%TMPF%" echo.
>>"%TMPF%" echo Project-specific rules live in that project's own `AGENTS.md`, and take
>>"%TMPF%" echo precedence over anything here.
>>"%TMPF%" echo.
>>"%TMPF%" echo ## Communication
>>"%TMPF%" echo.
>>"%TMPF%" echo Reply in %LANG_ARG%. Write code, comments, commit messages, variable names, and
>>"%TMPF%" echo file names in English.
>>"%TMPF%" echo.
endlocal
type "%TPL%\core.md" >> "%TMPF%"
for /l %%j in (1,1,%CN%) do (
    >>"%TMPF%" echo.
    >>"%TMPF%" echo ---
    >>"%TMPF%" echo.
    type "%ROLES_DIR%\!CHOSE_%%j!.md" >> "%TMPF%"
)
REM Appended verbatim and never parsed: the one place a user's own
REM machine-specific rules survive an update.
if exist "%SCRIPT_DIR%\local.md" (
    >>"%TMPF%" echo.
    >>"%TMPF%" echo ---
    >>"%TMPF%" echo.
    type "%SCRIPT_DIR%\local.md" >> "%TMPF%"
)

set CHANGED=1
if exist "%TARGET%" (
    fc /b "%TMPF%" "%TARGET%" >nul 2>&1
    if not errorlevel 1 set CHANGED=0
)
move /y "%TMPF%" "%TARGET%" >nul
if errorlevel 1 (
    echo   [FAIL] Cannot write %TARGET%
    if exist "%TMPF%" del "%TMPF%" >nul 2>&1
    exit /b 1
)

if "%CHOSEN%"=="" (set "SHOWR=core only") else (set "SHOWR=%CHOSEN%")
for %%f in ("%TARGET%") do set "BYTES=%%~zf"
if "%CHANGED%"=="0" (
    echo   [ OK ] %TARGET% already current ^(%SHOWR%, %BYTES% bytes^)
) else (
    echo   [ OK ] Wrote %TARGET% ^(%SHOWR%, %BYTES% bytes^)
    echo   [INFO] Reply language: !LANG_ARG!
    REM dsh's default budget for the whole rendered instruction baseline.
    if %BYTES% GTR 65536 echo   [WARN] That is over dsh's default 65536-byte instruction budget - it will be truncated.
    echo   [INFO] Rules reach only a session started AFTER this. Restart any open dsh session.
)
exit /b 0

:help
echo.
echo   agents.bat                              regenerate using the remembered roles
echo   agents.bat --role=figma,visual-assets   set the roles for this machine
echo   agents.bat --role=none                  core rules only, no role block
echo   agents.bat --show                       print the target path and current roles
echo.
echo   Writes the shared agent rules to %%USERPROFILE%%\.dsh\AGENTS.md, which dsh
echo   loads into every session of every project. Project-specific rules belong
echo   in that project's own AGENTS.md - see templates\project.example.md.
echo.
exit /b 0

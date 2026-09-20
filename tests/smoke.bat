@echo off
setlocal EnableDelayedExpansion
REM Smoke test for agents.bat, verify.bat, ensure-npm-path.bat and check.bat,
REM safe to run in CI or by hand.
REM
REM   tests\smoke.bat
REM
REM Everything runs against a throwaway DSH_HOME under %TEMP%, so a real
REM machine's AGENTS.md, credentials, or dsh install are never read or
REM touched. This is not a substitute for running setup.bat/update.bat for
REM real - it only proves agents.bat and verify.bat still behave the way the
REM rest of this repo (README, SETUP.md, CHANGELOG) says they do.

set "SCRIPT_DIR=%~dp0.."
for %%i in ("%SCRIPT_DIR%") do set "SCRIPT_DIR=%%~fi"
cd /d "%SCRIPT_DIR%" || exit /b 1

set "SANDBOX=%TEMP%\dsh-setup-smoke-%RANDOM%%RANDOM%"
set "DSH_HOME=%SANDBOX%\dsh"
mkdir "%DSH_HOME%" 2>nul
set "RULES=%DSH_HOME%\AGENTS.md"
set "OUT=%SANDBOX%\out.txt"
set FAILED=0

echo.
echo agents.bat --role=none
call .\agents.bat --role=none < nul >"%OUT%" 2>&1
if errorlevel 1 (call :fail "exited non-zero" & type "%OUT%") else (call :pass "exits 0")
if exist "%RULES%" (call :pass "AGENTS.md written") else (call :fail "AGENTS.md missing")
findstr /c:"roles:  -->" "%RULES%" >nul 2>&1
if errorlevel 1 (call :fail "stamp did not record empty roles") else (call :pass "stamp records no roles")

echo.
echo agents.bat --role=figma
call .\agents.bat --role=figma < nul >"%OUT%" 2>&1
if errorlevel 1 (call :fail "exited non-zero" & type "%OUT%") else (call :pass "exits 0")
findstr /c:"roles: figma" "%RULES%" >nul 2>&1
if errorlevel 1 (call :fail "stamp missing figma") else (call :pass "stamp records the figma role")
findstr /c:"Figma" "%RULES%" >nul 2>&1
if errorlevel 1 (call :fail "no Figma content found") else (call :pass "role block assembled into AGENTS.md")

echo.
echo agents.bat --no-ask with no rules file yet
del "%RULES%" 2>nul
call .\agents.bat --no-ask < nul >"%OUT%" 2>&1
if errorlevel 1 (call :fail "exited non-zero" & type "%OUT%") else (call :pass "exits 0, does not prompt")
findstr /c:"[INFO]" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "no explanation printed") else (call :pass "explains itself instead of asking")
if exist "%RULES%" (call :pass "AGENTS.md written") else (call :fail "AGENTS.md missing")

echo.
echo agents.bat --role=bogus is rejected
call .\agents.bat --role=bogus < nul >"%OUT%" 2>&1
if errorlevel 1 (call :pass "exits non-zero") else (call :fail "should have exited non-zero")
findstr /c:"Unknown role" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "no explanation printed") else (call :pass "explains why")

echo.
echo agents.bat --show
call .\agents.bat --show < nul >"%OUT%" 2>&1
if errorlevel 1 (call :fail "exited non-zero") else (call :pass "exits 0")
findstr /c:"target :" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "missing target line") else (call :pass "prints the target path")

echo.
echo verify.bat reports failure with no Figma token set
set "CI=true"
set "FIGMA_ACCESS_TOKEN="
set "ENABLE_MCP_APPS="
call .\verify.bat >"%OUT%" 2>&1
set "VERIFY_EXIT=!errorlevel!"
if "!VERIFY_EXIT!"=="1" (call :pass "exits 1") else (call :fail "exited !VERIFY_EXIT!, expected 1" & type "%OUT%")
findstr /c:"[FAIL]" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "no FAIL line printed") else (call :pass "prints at least one FAIL")

echo.
echo plugins\figma-bridge\lib\migrate.js removes a hand-copied legacy entry
set "PROFILE_CFG=%DSH_HOME%\profiles\web\cordis.patch.yml"
mkdir "%DSH_HOME%\profiles\web" 2>nul
(
echo # Your patch layer for this dsh profile, applied after every bundle layer:
echo - insert:
echo     - id: mcp-figma
echo       name: '@deepseek-ai/dsh-mcp-client'
echo       config:
echo         serverName: figma
echo         transport: stdio
echo         command: npx
echo         args: ['-y', 'figma-console-mcp@latest']
) > "%PROFILE_CFG%"
node plugins\figma-bridge\lib\migrate.js >"%OUT%" 2>&1
if errorlevel 1 (call :fail "exited non-zero" & type "%OUT%") else (call :pass "exits 0")
findstr /c:"serverName: figma" "%PROFILE_CFG%" >nul 2>&1
if errorlevel 1 (call :pass "legacy entry removed") else (call :fail "legacy entry still present")
if exist "%PROFILE_CFG%.bak" (call :pass "backup written") else (call :fail "no .bak written")
node plugins\figma-bridge\lib\migrate.js >"%OUT%" 2>&1
if errorlevel 1 (call :fail "second run exited non-zero" & type "%OUT%") else (call :pass "second run exits 0")
findstr /c:"no legacy entry found" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "second run did not report a no-op" & type "%OUT%") else (call :pass "second run is a clean no-op")

echo.
echo ensure-npm-path.bat when dsh is not on PATH
REM Refuse to run without the hook: without it this section would write the fake
REM npm folder into the REAL user PATH. And check afterwards that it did not.
findstr /c:"DSH_TEST_ENV_KEY" ensure-npm-path.bat >nul 2>&1
if errorlevel 1 (call :fail "ensure-npm-path.bat has no DSH_TEST_ENV_KEY hook - skipped, it would write to the real PATH" & goto :ep_done)
call :regdump "%SANDBOX%\real1.txt" Environment
REM The persistent write goes to a scratch key under HKCU, never to the real
REM Environment key - DSH_TEST_ENV_KEY is the hook for that.
set "EP=%SANDBOX%\ep"
set "EP_PREFIX=%EP%\prefix (x86)\npm"
set "EP_EMPTY=%EP%\empty"
set "EP_CASE=%SCRIPT_DIR%\tests\ensure-npm-path-case.bat"
set "DSH_TEST_ENV_KEY=dshsmoke%RANDOM%%RANDOM%"
mkdir "%EP_PREFIX%" "%EP_EMPTY%" 2>nul
echo @echo off> "%EP_PREFIX%\dsh.cmd"
powershell -NoProfile -Command "$k=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('%DSH_TEST_ENV_KEY%'); $k.SetValue('Path','%%USERPROFILE%%\bin',[Microsoft.Win32.RegistryValueKind]::ExpandString); $k.Close()" >nul 2>&1
setlocal
call "%EP_CASE%" "%EP_PREFIX%" offpath >"%OUT%" 2>&1
endlocal
findstr /c:"EXIT=0" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "did not exit 0" & type "%OUT%") else (call :pass "exits 0")
findstr /c:"DSH=found" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "dsh is still not found afterwards" & type "%OUT%") else (call :pass "dsh is found afterwards, folder with parentheses and a space")
findstr /c:"added" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "did not say it changed PATH") else (call :pass "says it changed PATH")
call :regdump "%SANDBOX%\reg1.txt" %DSH_TEST_ENV_KEY%
findstr /b /c:"ExpandString|" "%SANDBOX%\reg1.txt" >nul 2>&1
if errorlevel 1 (call :fail "saved PATH is not REG_EXPAND_SZ") else (call :pass "saved PATH stays REG_EXPAND_SZ")
findstr /c:"%%USERPROFILE%%\bin" "%SANDBOX%\reg1.txt" >nul 2>&1
if errorlevel 1 (call :fail "an existing entry with a variable in it was expanded or lost") else (call :pass "existing entries with a variable in them are kept unexpanded")
findstr /c:"prefix (x86)\npm" "%SANDBOX%\reg1.txt" >nul 2>&1
if errorlevel 1 (call :fail "npm folder not saved") else (call :pass "npm folder saved for new terminals")
setlocal
call "%EP_CASE%" "%EP_PREFIX%" offpath >"%OUT%" 2>&1
endlocal
call :regdump "%SANDBOX%\reg2.txt" %DSH_TEST_ENV_KEY%
fc "%SANDBOX%\reg1.txt" "%SANDBOX%\reg2.txt" >nul 2>&1
if errorlevel 1 (call :fail "second run changed the saved PATH again") else (call :pass "second run adds no duplicate")
setlocal
call "%EP_CASE%" "%EP_PREFIX%" onpath >"%OUT%" 2>&1
endlocal
findstr /c:"[INFO]" "%OUT%" >nul 2>&1
if errorlevel 1 (call :pass "silent when dsh is already reachable") else (call :fail "printed something although dsh was reachable" & type "%OUT%")
call :regdump "%SANDBOX%\reg3.txt" %DSH_TEST_ENV_KEY%
fc "%SANDBOX%\reg1.txt" "%SANDBOX%\reg3.txt" >nul 2>&1
if errorlevel 1 (call :fail "changed the saved PATH although dsh was reachable") else (call :pass "leaves the saved PATH alone when dsh is reachable")
setlocal
call "%EP_CASE%" "%EP_EMPTY%" offpath >"%OUT%" 2>&1
endlocal
findstr /c:"EXIT=1" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "should exit 1 when the folder holds no dsh" & type "%OUT%") else (call :pass "exits 1 when the folder holds no dsh")
findstr /c:"[WARN]" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "no warning printed") else (call :pass "explains what is wrong")
call :regdump "%SANDBOX%\reg4.txt" %DSH_TEST_ENV_KEY%
fc "%SANDBOX%\reg1.txt" "%SANDBOX%\reg4.txt" >nul 2>&1
if errorlevel 1 (call :fail "wrote PATH for a broken install") else (call :pass "does not touch the saved PATH for a broken install")
powershell -NoProfile -Command "[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree('%DSH_TEST_ENV_KEY%', $false)" >nul 2>&1
set "DSH_TEST_ENV_KEY="
call :regdump "%SANDBOX%\real2.txt" Environment
fc "%SANDBOX%\real1.txt" "%SANDBOX%\real2.txt" >nul 2>&1
if errorlevel 1 (call :fail "the REAL user PATH changed while testing - check HKCU\Environment") else (call :pass "the real user PATH was not touched")
:ep_done

echo.
echo check.bat against a throwaway origin
REM origin.git <- work (holds check.bat) and other (pushes the "new commit").
REM check.bat is only ever answered "N", so update.bat is never reached.
set "CK=%SANDBOX%\ck"
set "GIT=git -c user.name=smoke -c user.email=smoke@example.invalid -c core.autocrlf=false"
mkdir "%CK%" 2>nul
git init -q --bare -b main "%CK%\origin.git" >nul 2>&1
git init -q -b main "%CK%\work" >nul 2>&1
copy /y check.bat "%CK%\work\check.bat" >nul
%GIT% -C "%CK%\work" add -A >nul 2>&1
%GIT% -C "%CK%\work" commit -q -m init >nul 2>&1
git -C "%CK%\work" remote add origin "%CK%\origin.git" >nul 2>&1
git -C "%CK%\work" push -q -u origin main >nul 2>&1
setlocal
call "%CK%\work\check.bat" >"%OUT%" 2>&1
set "CHECK_EXIT=!errorlevel!"
endlocal & set "CHECK_EXIT=%CHECK_EXIT%"
cd /d "%SCRIPT_DIR%"
if "%CHECK_EXIT%"=="0" (call :pass "up to date: exits 0") else (call :fail "up to date: exited %CHECK_EXIT%" & type "%OUT%")
findstr /c:"Already up to date" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "did not say it is up to date" & type "%OUT%") else (call :pass "says it is up to date")
git clone -q "%CK%\origin.git" "%CK%\other" >nul 2>&1
echo new> "%CK%\other\new.txt"
%GIT% -C "%CK%\other" add -A >nul 2>&1
%GIT% -C "%CK%\other" commit -q -m "a new commit" >nul 2>&1
git -C "%CK%\other" push -q origin main >nul 2>&1
git -C "%CK%\work" rev-parse HEAD >"%SANDBOX%\head1.txt"
echo N| call "%CK%\work\check.bat" >"%OUT%" 2>&1
cd /d "%SCRIPT_DIR%"
findstr /c:"update(s) available" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "did not report the new commit" & type "%OUT%") else (call :pass "reports a new commit")
findstr /c:"Skipped" "%OUT%" >nul 2>&1
if errorlevel 1 (call :fail "answering N did not skip" & type "%OUT%") else (call :pass "answering N skips the update")
git -C "%CK%\work" rev-parse HEAD >"%SANDBOX%\head2.txt"
fc "%SANDBOX%\head1.txt" "%SANDBOX%\head2.txt" >nul 2>&1
if errorlevel 1 (call :fail "checkout moved although the answer was N") else (call :pass "checkout is left where it was")

rd /s /q "%SANDBOX%" 2>nul
echo.
if "%FAILED%"=="1" (echo some smoke checks failed) else (echo all smoke checks passed)
exit /b %FAILED%

:regdump
REM %1 = output file, %2 = key under HKCU to dump
powershell -NoProfile -Command "$k=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('%~2'); if ($k) { $k.GetValueKind('Path').ToString() + '|' + $k.GetValue('Path','',[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); $k.Close() }" >"%~1" 2>&1
exit /b 0

:pass
echo   [ OK ] %~1
exit /b 0

:fail
echo   [FAIL] %~1
set FAILED=1
exit /b 0

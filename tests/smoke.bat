@echo off
setlocal EnableDelayedExpansion
REM Smoke test for agents.bat and verify.bat, safe to run in CI or by hand.
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

rd /s /q "%SANDBOX%" 2>nul
echo.
if "%FAILED%"=="1" (echo some smoke checks failed) else (echo all smoke checks passed)
exit /b %FAILED%

:pass
echo   [ OK ] %~1
exit /b 0

:fail
echo   [FAIL] %~1
set FAILED=1
exit /b 0

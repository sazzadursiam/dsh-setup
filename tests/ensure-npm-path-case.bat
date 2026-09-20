@echo off
REM Helper for tests\smoke.bat: one run of ensure-npm-path.bat in a clean PATH.
REM
REM   ensure-npm-path-case.bat <npm prefix folder> <onpath|offpath>
REM
REM PATH is rebuilt from scratch - system folders, PowerShell, and a fake npm
REM that reports <npm prefix folder> as its global prefix - so the machine's own
REM npm and dsh cannot leak in. "onpath" also puts the prefix folder on PATH, the
REM way a healthy machine looks. Prints EXIT= and DSH= for the caller to assert
REM on. Caller wraps this in setlocal/endlocal: it replaces PATH.
set "PATH=%SystemRoot%\System32;%SystemRoot%\System32\WindowsPowerShell\v1.0;%~dp0fake-npm"
if /i "%~2"=="onpath" set "PATH=%PATH%;%~1"
set "FAKE_PREFIX=%~1"
call "%~dp0..\ensure-npm-path.bat"
echo EXIT=%errorlevel%
where dsh >nul 2>&1
if errorlevel 1 (echo DSH=missing) else (echo DSH=found)

@echo off
REM Make sure the `dsh` command npm just installed can actually be run.
REM
REM `npm install -g` puts commands in npm's global prefix folder
REM (%APPDATA%\npm by default). That folder is on PATH only if something put it
REM there - the Node installer usually does, but not always - and when it is
REM missing, the very next step of setup fails with "'dsh' is not recognized",
REM the web profile and plugins are silently skipped, and the script still
REM ends on "INSTALL COMPLETE".
REM
REM What this does, only when `dsh` cannot be found:
REM   1. adds the folder to PATH for the rest of the calling script, and
REM   2. saves it to the user's PATH so new terminals find `dsh` too.
REM When `dsh` is already reachable it changes nothing and prints nothing.
REM
REM Exit code: 0 = dsh is reachable, 1 = it is not and could not be fixed.
REM
REM No setlocal, on purpose: the PATH change has to reach the calling script.
REM Callers use `call`; every variable set here is cleared before returning.
REM DSH_TEST_ENV_KEY points the persistent write at a scratch registry key
REM instead of HKCU\Environment - used only by tests\smoke.bat, never set it.
REM The persistent write goes to the registry directly as REG_EXPAND_SZ.
REM [Environment]::SetEnvironmentVariable would store PATH as REG_SZ and
REM freeze every %VAR% in it to its current value.

where dsh >nul 2>&1
if not errorlevel 1 exit /b 0

set "DSH_NPM_BIN="
for /f "usebackq delims=" %%p in (`npm config get prefix 2^>nul`) do set "DSH_NPM_BIN=%%p"
if not defined DSH_NPM_BIN goto :cannot
if not exist "%DSH_NPM_BIN%\" goto :cannot

set "PATH=%DSH_NPM_BIN%;%PATH%"
where dsh >nul 2>&1
if errorlevel 1 goto :cannot

echo   [INFO] dsh was not on PATH - added %DSH_NPM_BIN% to it.
set "DSH_PS=$d=$env:DSH_NPM_BIN.TrimEnd('\'); $kn='Environment'; if ($env:DSH_TEST_ENV_KEY) { $kn=$env:DSH_TEST_ENV_KEY }; $k=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($kn,$true); $p=[string]$k.GetValue('Path','',[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); $have=@($p -split ';' | Where-Object {$_} | ForEach-Object {[Environment]::ExpandEnvironmentVariables($_).TrimEnd('\')}); if ($have -notcontains $d) { $k.SetValue('Path',(($p.TrimEnd(';')+';'+$env:DSH_NPM_BIN).TrimStart(';')),[Microsoft.Win32.RegistryValueKind]::ExpandString); [Environment]::SetEnvironmentVariable('DSH_PATH_REFRESH',$null,'User') }; $k.Close()"
powershell -NoProfile -ExecutionPolicy Bypass -Command "%DSH_PS%" >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Could not save it for new terminals. Add that folder to your
    echo          user PATH by hand, or `dsh` will not be found next time.
) else (
    echo          Saved for new terminals too - no need to edit PATH by hand.
)
set "DSH_PS="
set "DSH_NPM_BIN="
exit /b 0

:cannot
echo   [WARN] dsh is not on PATH, and adding npm's global folder did not help.
echo          Check that the dsh install above finished without errors, then
echo          open a new terminal and run: where dsh
set "DSH_PS="
set "DSH_NPM_BIN="
exit /b 1

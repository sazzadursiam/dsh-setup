@echo off
REM Stand-in for npm in tests\smoke.bat: answers `npm config get prefix` with %FAKE_PREFIX%.
echo %FAKE_PREFIX%

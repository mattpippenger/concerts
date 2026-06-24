@echo off
REM ===========================================================================
REM  Concert Tracker -- double-click to refresh data from the spreadsheet
REM  and open the dashboard in your default browser.
REM ===========================================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-data.ps1"
if %ERRORLEVEL% NEQ 0 (
  echo.
  echo  Something went wrong. See the messages above.
  pause
)

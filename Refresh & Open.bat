@echo off
REM ===========================================================================
REM  Concert Tracker -- double-click to refresh data from the spreadsheet,
REM  push the update to GitHub (live site updates in ~30 seconds), and open
REM  the local dashboard.
REM ===========================================================================
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-data.ps1"
if %ERRORLEVEL% NEQ 0 (
  echo.
  echo  Something went wrong. See the messages above.
  pause
  exit /b 1
)

echo.
echo  Pushing updates to GitHub...
git add .
git diff --cached --quiet
if %ERRORLEVEL% EQU 0 (
  echo  No changes to push.
) else (
  for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyy-MM-dd HH:mm\")"') do set STAMP=%%i
  git commit -m "Update concert data (%STAMP%)"
  git push
  if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  Push failed -- check your internet connection and try again.
    pause
  ) else (
    echo.
    echo  Done! Live site updates in about 30 seconds:
    echo  https://mattpippenger.github.io/concerts/
  )
)

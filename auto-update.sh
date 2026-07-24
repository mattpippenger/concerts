#!/bin/bash
# =============================================================================
#  auto-update.sh  --  Concert Tracker weekly auto-update (Mac)
#
#  Run by launchd on a schedule. Checks whether Concerts.xlsm has changed
#  since the last commit; if so, rebuilds data.js and pushes to GitHub.
#  Install instructions: see com.mattpippenger.concerttracker.plist
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$HOME/Library/Logs/concert-tracker-update.log"

# Rotate log if it exceeds 1 MB
if [ -f "$LOG" ] && [ "$(stat -f%z "$LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
  mv "$LOG" "${LOG}.bak"
fi

exec >> "$LOG" 2>&1
echo ""
echo "=== $(date '+%Y-%m-%d %H:%M:%S') Concert Tracker auto-update ==="

# Locate the Dropbox spreadsheet (handles both legacy and new Dropbox paths)
EXCEL=""
for candidate in \
  "$HOME/Dropbox/Concerts.xlsm" \
  "$HOME/Library/CloudStorage/Dropbox/Concerts.xlsm" \
  "$HOME/Library/CloudStorage/Dropbox-Personal/Concerts.xlsm"; do
  if [ -f "$candidate" ]; then
    EXCEL="$candidate"
    break
  fi
done

if [ -z "$EXCEL" ]; then
  echo "ERROR: Concerts.xlsm not found in any expected Dropbox location."
  echo "Check that Dropbox is running and synced on this Mac."
  exit 1
fi

echo "Spreadsheet: $EXCEL"

# Compare spreadsheet modification time to last git commit timestamp.
# Skip rebuild if nothing has changed since the last push.
LAST_COMMIT=$(git -C "$REPO_DIR" log -1 --format="%ct" 2>/dev/null || echo 0)
EXCEL_MTIME=$(stat -f "%m" "$EXCEL" 2>/dev/null || echo 0)

if [ "$EXCEL_MTIME" -le "$LAST_COMMIT" ]; then
  echo "Spreadsheet unchanged since last push. Nothing to do."
  exit 0
fi

echo "Changes detected — rebuilding..."

# Require pwsh (PowerShell for Mac). Install with: brew install powershell
if ! command -v pwsh &>/dev/null; then
  echo "ERROR: pwsh not found. Install PowerShell: brew install powershell"
  exit 1
fi

pwsh -NonInteractive -ExecutionPolicy Bypass -File "$REPO_DIR/build-data.ps1" -NoOpen
BUILD_EXIT=$?

if [ $BUILD_EXIT -ne 0 ]; then
  echo "ERROR: build-data.ps1 exited with code $BUILD_EXIT"
  exit $BUILD_EXIT
fi

echo "Build complete. Pushing to GitHub..."
git -C "$REPO_DIR" add .

if git -C "$REPO_DIR" diff --cached --quiet; then
  echo "No data changes detected in output. Nothing to push."
else
  STAMP=$(date '+%Y-%m-%d')
  git -C "$REPO_DIR" commit -m "Auto-update concert data ($STAMP)"
  git -C "$REPO_DIR" push
  echo "Done. Live site will update in ~30 seconds: https://mattpippenger.github.io/concerts/"
fi

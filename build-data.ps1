<#
  build-data.ps1  --  Concert Tracker data builder + launcher

  Reads the live Concerts workbook, parses the "Master Show List" sheet,
  cleans the data, and writes data.js (consumed by index.html via <script src>).
  Then opens the dashboard in the default browser (unless -NoOpen is passed).

  Usage:  double-click "Refresh & Open.bat", or:
          powershell -ExecutionPolicy Bypass -File build-data.ps1
          pwsh -NonInteractive -File build-data.ps1 -NoOpen   (Mac / headless)

  NOTE: the artist alias map below is kept in sync (by hand) with the one in
  config.js. PowerShell can't read JS, so any name-merge must be added in BOTH.
#>
param(
  [switch]$NoOpen   # skip launching the browser (used by auto-update.sh on Mac)
)

$ErrorActionPreference = 'Stop'

# ---- settings --------------------------------------------------------------
# Detect platform and set path to the Dropbox spreadsheet accordingly.
if ($IsWindows -or (-not (Test-Path variable:IsWindows))) {
  $SourcePath = 'C:\Users\matt.pippenger\Dropbox\Concerts.xlsm'
} else {
  # Mac: try both the legacy Dropbox path and the newer CloudStorage location
  $macPaths = @(
    (Join-Path $HOME 'Dropbox/Concerts.xlsm'),
    (Join-Path $HOME 'Library/CloudStorage/Dropbox/Concerts.xlsm'),
    (Join-Path $HOME 'Library/CloudStorage/Dropbox-Personal/Concerts.xlsm')
  )
  $SourcePath = $macPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $SourcePath) { $SourcePath = Join-Path $HOME 'Dropbox/Concerts.xlsm' }  # fallback for error msg
}
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutFile    = Join-Path $ScriptDir 'data.js'
$IndexFile  = Join-Path $ScriptDir 'index.html'
$CacheFile  = Join-Path $ScriptDir 'setlist-cache.json'

# ---- setlist.fm direct links (optional) ------------------------------------
# The API key is read from "setlist-api-key.txt" next to this script (that file is
# git-ignored so the key never gets committed). Get a FREE key at
# https://www.setlist.fm/settings/api and paste it as the only line of that file.
# Without the file, every show just uses a setlist.fm SEARCH link (no network).
# With a key, each show is resolved at refresh time: if the search finds EXACTLY
# one setlist, the ticket links straight to that page; otherwise it falls back to
# the search link. Results are cached in setlist-cache.json so repeat refreshes
# only query shows that are new or changed.
$SetlistApiKey = ''
$KeyFile = Join-Path $ScriptDir 'setlist-api-key.txt'
if (Test-Path $KeyFile) { $SetlistApiKey = (Get-Content $KeyFile -Raw).Trim() }

# NOTE: band names are kept EXACTLY as recorded in the spreadsheet (e.g. each show
# shows the band Sammy actually toured under). Logical *grouping* (so all of Sammy
# Hagar's solo bands count under one "Sammy Hagar" artist while Van Halen and
# Chickenfoot stay separate) is handled in config.js + app.js at display time, so
# the original tour names are never lost.

# Values that mean "nothing" in any text cell.
$JunkValues = @('none', '??', 'n/a', 'na', '-', '')

# Excel 1904 date system epoch (workbook has date1904="1").
$Epoch1904 = [datetime]'1904-01-01'

# ---------------------------------------------------------------------------

function Read-ZipEntryText {
  param([System.IO.Compression.ZipArchive]$Zip, [string]$EntryName)
  $entry = $Zip.GetEntry($EntryName)
  if ($null -eq $entry) { throw "Entry '$EntryName' not found in workbook." }
  $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Clean-Text {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  $v = $Value.Trim()
  if ($JunkValues -contains $v.ToLower()) { return '' }
  return $v
}

# Load the setlist cache as a hashtable (key -> {url, tourName}).
# Old-format entries (plain strings) are read as {url=str, tourName=''}.
function Load-Cache {
  param([string]$Path)
  $h = @{}
  if (Test-Path $Path) {
    try {
      $obj = Get-Content $Path -Raw | ConvertFrom-Json
      foreach ($p in $obj.PSObject.Properties) {
        $v = $p.Value
        if ($v -is [string]) {
          $h[$p.Name] = @{ url = $v; tourName = '' }
        } else {
          $h[$p.Name] = @{ url = [string]$v.url; tourName = [string]$v.tourName }
        }
      }
    } catch { Write-Host "  (couldn't read setlist cache; starting fresh)" -ForegroundColor Yellow }
  }
  return $h
}

# Query setlist.fm; return @{url; tourName} when exactly one setlist is found,
# @{url=''; tourName=''} for no/ambiguous match, or $null on transient errors.
function Resolve-Setlist {
  param([string]$Artist, [string]$DateIso, [string]$ApiKey)
  $empty = @{ url = ''; tourName = '' }
  if ([string]::IsNullOrEmpty($Artist) -or [string]::IsNullOrEmpty($DateIso)) { return $empty }
  $apiDate = ''
  try { $apiDate = ([datetime]$DateIso).ToString('dd-MM-yyyy') } catch { return $empty }
  $uri = "https://api.setlist.fm/rest/1.0/search/setlists?artistName=" +
         [System.Uri]::EscapeDataString($Artist) + "&date=$apiDate"
  $headers = @{ 'x-api-key' = $ApiKey; 'Accept' = 'application/json' }
  try {
    $resp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 20
    if ($null -ne $resp -and $resp.total -eq 1) {
      $first = $resp.setlist
      if ($first -is [array]) { $first = $first[0] }
      if ($first -and $first.url) {
        $tourName = ''
        if ($first.tour -and $first.tour.name) { $tourName = [string]$first.tour.name }
        return @{ url = [string]$first.url; tourName = $tourName }
      }
    }
    return $empty   # zero or multiple matches -> use search fallback
  } catch {
    $code = $null
    try { $code = [int]$_.Exception.Response.StatusCode } catch {}
    if ($code -eq 404) { return $empty }   # API returns 404 for "no setlists found"
    return $null                           # other errors: leave unresolved (retry next time)
  }
}


Write-Host ""
Write-Host "  Concert Tracker  --  building data" -ForegroundColor Cyan
Write-Host "  source: $SourcePath"

if (-not (Test-Path $SourcePath)) {
  Write-Host ""
  Write-Host "  ERROR: workbook not found at:" -ForegroundColor Red
  Write-Host "         $SourcePath" -ForegroundColor Red
  Write-Host "  Edit `$SourcePath at the top of build-data.ps1 if it moved." -ForegroundColor Yellow
  Read-Host "  Press Enter to close"
  exit 1
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Copy into memory so an open/locked Dropbox file (Excel) doesn't block us.
$bytes  = [System.IO.File]::ReadAllBytes($SourcePath)
$stream = New-Object System.IO.MemoryStream(,$bytes)
$zip    = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Read)

try {
  # --- shared strings ---
  [xml]$ssXml = Read-ZipEntryText -Zip $zip -EntryName 'xl/sharedStrings.xml'
  $shared = New-Object System.Collections.Generic.List[string]
  foreach ($si in $ssXml.sst.si) {
    # InnerText concatenates all <t> runs (handles rich-text multi-run strings).
    $shared.Add([string]$si.InnerText)
  }
  Write-Host "  shared strings: $($shared.Count)"

  # --- master show list (sheet3.xml) ---
  [xml]$shXml = Read-ZipEntryText -Zip $zip -EntryName 'xl/worksheets/sheet3.xml'

  $shows      = New-Object System.Collections.Generic.List[object]
  $yearMismatch = 0
  $rowCount   = 0

  foreach ($row in $shXml.worksheet.sheetData.row) {
    $r = [int]$row.r
    if ($r -lt 2) { continue }   # skip header

    # Build a column-letter -> value map for this row.
    $cells = @{}
    foreach ($c in @($row.c)) {
      if ($null -eq $c) { continue }
      $ref = [string]$c.r
      if ([string]::IsNullOrEmpty($ref)) { continue }
      $col = ($ref -replace '[0-9]', '')
      $val = $null
      if ($c.t -eq 's') {
        $idx = [int]$c.v
        if ($idx -ge 0 -and $idx -lt $shared.Count) { $val = $shared[$idx] }
      } elseif ($c.t -eq 'inlineStr') {
        $val = [string]$c.is.t
      } else {
        $val = [string]$c.v   # number / formula result
      }
      $cells[$col] = $val
    }

    $headliner = Clean-Text $cells['A']
    if ([string]::IsNullOrEmpty($headliner)) { continue }  # no headliner = not a show row

    # Supporting bands B..E -- names kept exactly as recorded.
    $bands = New-Object System.Collections.Generic.List[string]
    $bands.Add($headliner)
    foreach ($col in 'B','C','D','E') {
      $b = Clean-Text $cells[$col]
      if (-not [string]::IsNullOrEmpty($b)) { $bands.Add($b) }
    }

    # Date (col F) -- numeric serial in 1904 system.
    $dateStr = $null
    $year    = $null
    $fRaw    = $cells['F']
    if (-not [string]::IsNullOrEmpty($fRaw)) {
      $serial = 0.0
      if ([double]::TryParse($fRaw, [ref]$serial)) {
        $dt = $Epoch1904.AddDays($serial)
        if ($dt.Year -ge 1985 -and $dt.Year -le 2100) {
          $dateStr = $dt.ToString('yyyy-MM-dd')
          $year    = $dt.Year
        }
      }
    }
    # Cross-check against stored YEAR (col G) when present.
    $gRaw = $cells['G']
    if (-not [string]::IsNullOrEmpty($gRaw)) {
      $gYear = 0
      if ([int]::TryParse($gRaw, [ref]$gYear) -and $gYear -ge 1985) {
        if ($null -eq $year) { $year = $gYear }
        elseif ($year -ne $gYear) { $yearMismatch++ }
      }
    }

    $venue = Clean-Text $cells['H']

    # City/State from col I (e.g. "Noblesville, IN").
    $city = ''; $state = ''
    $cs = Clean-Text $cells['I']
    if (-not [string]::IsNullOrEmpty($cs)) {
      $parts = $cs.Split(',')
      $city  = $parts[0].Trim()
      if ($parts.Count -ge 2) { $state = ($parts[1..($parts.Count-1)] -join ',').Trim() }
    }

    $shows.Add([ordered]@{
      headliner  = $headliner
      bands      = @($bands)
      date       = $dateStr
      year       = $year
      venue      = $venue
      city       = $city
      state      = $state
      tourName   = ''   # filled from setlist.fm API when available
      setlistUrl = ''   # filled below when a direct setlist.fm link is found
    })
    $rowCount++
  }

  Write-Host "  shows parsed:   $rowCount"
  if ($yearMismatch -gt 0) {
    Write-Host "  WARNING: $yearMismatch rows where computed year != stored YEAR (col G)." -ForegroundColor Yellow
    Write-Host "           1904 epoch may need adjustment; using stored YEAR where needed." -ForegroundColor Yellow
  }

  # --- resolve direct setlist.fm links (only if an API key is configured) ---
  if (-not [string]::IsNullOrWhiteSpace($SetlistApiKey)) {
    Write-Host "  resolving setlist.fm links..." -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $cache = Load-Cache -Path $CacheFile
    $direct = 0; $queries = 0; $errors = 0
    foreach ($s in $shows) {
      if ([string]::IsNullOrEmpty($s.date)) { continue }   # need a date to match precisely
      $key = "$($s.headliner)|$($s.date)|$($s.venue)"
      if ($cache.ContainsKey($key)) {
        $cached = $cache[$key]
        $s.setlistUrl = $cached.url
        $s.tourName   = $cached.tourName
      } else {
        $result = Resolve-Setlist -Artist $s.headliner -DateIso $s.date -ApiKey $SetlistApiKey
        if ($null -eq $result) { $errors++ }   # transient error: don't cache, retry next run
        else {
          $cache[$key]  = $result
          $s.setlistUrl = $result.url
          $s.tourName   = $result.tourName
          Start-Sleep -Milliseconds 600        # stay under setlist.fm's ~2 req/sec limit
        }
        $queries++
      }
      if ($s.setlistUrl) { $direct++ }
    }
    # persist cache
    try {
      ($cache | ConvertTo-Json -Depth 3) | Set-Content -Path $CacheFile -Encoding UTF8
    } catch { Write-Host "  (couldn't save setlist cache)" -ForegroundColor Yellow }
    Write-Host "  direct setlist links: $direct  (live queries this run: $queries$(if($errors){"; $errors errored"}))" -ForegroundColor Green
  }

  # --- write data.js (UTF-8, no BOM) ---
  $meta = [ordered]@{
    generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    source      = $SourcePath
    showCount   = $rowCount
  }
  $showsJson = $shows | ConvertTo-Json -Depth 6
  $metaJson  = $meta  | ConvertTo-Json -Depth 4
  # ConvertTo-Json emits a bare object for single-element arrays; force array form.
  if ($rowCount -eq 1) { $showsJson = "[`n$showsJson`n]" }

  $js = "// Auto-generated by build-data.ps1 -- do not edit by hand.`r`n" +
        "window.CONCERT_DATA = $showsJson;`r`n" +
        "window.CONCERT_META = $metaJson;`r`n"

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($OutFile, $js, $utf8NoBom)
  Write-Host "  wrote: $OutFile" -ForegroundColor Green
}
finally {
  $zip.Dispose()
  $stream.Dispose()
}

# --- launch dashboard ---
if (-not $NoOpen) {
  if (Test-Path $IndexFile) {
    Write-Host "  opening dashboard..." -ForegroundColor Cyan
    Start-Process $IndexFile
  } else {
    Write-Host "  (index.html not found yet -- data.js is ready)" -ForegroundColor Yellow
  }
}
Write-Host ""

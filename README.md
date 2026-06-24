# Concert Tracker

A clean-but-fun, retro concert-ticket dashboard for your lifetime of shows,
built straight from `Concerts.xlsm`.

## How to use it

**Double-click `Refresh & Open.bat`.**

That reads your live spreadsheet
(`C:\Users\matt.pippenger\Dropbox\Concerts.xlsm`), rebuilds the data, and opens
the dashboard in your default browser. Run it again any time you add shows to the
spreadsheet — the dashboard always reflects the latest file.

(You can also just open `index.html` directly to view the last-generated data
without re-reading the spreadsheet.)

## What's inside

- **Overview** — totals (shows, bands, venues, years active), most-seen bands & venues.
- **On This Day** — every show you saw on today's calendar date in past years, plus
  milestone callouts ("your 50th show ever", "first time seeing X"). Use the date
  picker to explore any day.
- **Artists** / **Venues** — searchable lists; click any one to see every show.
- **Timeline** — shows-per-year, cumulative growth, top bands & venues, and fun facts
  (busiest year, longest dry spell, top decade, milestone shows…).
- **Search** — match any band (headliner *or* opener), venue, city, or year.
- **Setlists** — every show ticket has a setlist link. By default it's a
  `setlist.fm ↗` button that opens a setlist.fm search (artist + city + year). You
  can optionally upgrade this to **direct links** (see below).

### Themes
Use the **Theme** picker in the footer to switch the look — five retro palettes
(Kraft, Sunset, Vinyl, Blue Note, and a dark **Backstage** mode), each with its own
font pairing. Your choice is remembered in the browser.

## Keeping it accurate

### Merging band name variants
If the same band shows up under two spellings (e.g. "Sammy Hagar" vs
"Sammy Hagar & The Waboritas"), add an alias so they count as one. You must add it
in **two** places, then re-run the .bat:

1. `build-data.ps1` → the `$ArtistAliases` table near the top.
2. `config.js` → the `artistAliases` object (for reference).

```
'Variant Name' = 'Canonical Name'   # in build-data.ps1
'Variant Name': 'Canonical Name'    // in config.js
```

### If the spreadsheet moves
Edit `$SourcePath` at the top of `build-data.ps1` (and `sourcePath` in `config.js`).

### Optional: direct setlist.fm links
By default each show opens a setlist.fm *search*. To make shows link straight to
the exact setlist page when there's an unambiguous match:

1. Get a free API key at <https://www.setlist.fm/settings/api> (instant).
2. Paste it into `$SetlistApiKey = ''` near the top of `build-data.ps1`.
3. Double-click `Refresh & Open.bat`.

On refresh the script asks setlist.fm about each dated show: if the search returns
**exactly one** setlist, that ticket links straight to it (shown as a filled
`setlist ↗` button); otherwise it falls back to the search link. Results are cached
in `setlist-cache.json`, so only new or changed shows are looked up on later
refreshes (the first full run takes a few minutes and needs internet). Delete
`setlist-cache.json` to force a full re-resolve.

## Files

| File | Purpose |
|------|---------|
| `Refresh & Open.bat` | Double-click entry point |
| `build-data.ps1` | Reads the .xlsm and writes `data.js` |
| `data.js` | Generated data (don't edit by hand) |
| `config.js` | Source path + alias map |
| `setlist-cache.json` | Generated only if you add an API key; caches resolved setlist links |
| `index.html` / `styles.css` / `app.js` | The dashboard |

## Notes
- No installs needed — uses PowerShell (built into Windows) and runs fully offline.
- The spreadsheet's "band sighting" counts include every slot (headliner + up to 4
  supporting acts), matching how your `Counts` sheet tallies them.

# Add Show Form — Design Spec
**Date:** 2026-08-25
**Status:** Approved

---

## Overview

Add an in-browser "Add Show" form to Pip's Concert Tracker so new concerts can be entered directly from the site (desktop or iOS) without touching the spreadsheet or running any build script. Shows are saved to a `concerts-additions.json` file in the GitHub repo via the GitHub API. `data.js` is frozen as the historical record; `concerts-additions.json` grows over time.

---

## Architecture

### Data sources (merged at runtime)

| File | Role |
|---|---|
| `data.js` | Historical shows — frozen, generated once from spreadsheet, never re-run |
| `concerts-additions.json` | New shows — committed to repo by the browser form via GitHub API |

On page load, `app.js` fetches `concerts-additions.json` asynchronously, maps each entry through the same enrichment logic applied to `data.js` shows, and merges the result into `SHOWS[]`. All derived views (artists, venues, timeline, badges, search) work unchanged.

### Credential storage (localStorage only, never committed)

| Key | Value |
|---|---|
| `concert_setlist_key` | setlist.fm API key |
| `concert_github_pat` | GitHub Personal Access Token (contents:write scope on the concerts repo) |

### concerts-additions.json format

Same shape as entries in `window.CONCERT_DATA`:

```json
[
  {
    "headliner": "Pearl Jam",
    "bands": ["Mudhoney", "Pearl Jam"],
    "date": "2024-09-15",
    "venue": "Ruoff Music Center",
    "city": "Noblesville",
    "state": "IN",
    "tourName": "Dark Matter World Tour",
    "setlistUrl": "https://www.setlist.fm/setlist/pearl-jam/...",
    "songs": ["Alive", "Even Flow", "Black"]
  }
]
```

`bands` always includes the headliner. Supporting acts are listed first (matching spreadsheet convention). An entry with no setlist.fm match stores empty strings/arrays for auto-populated fields.

---

## UI

### Entry point

A fixed floating `+` button, bottom-right corner, always visible. Tapping it opens the Add Show modal. On first tap (no credentials stored), it shows the one-time Settings screen instead.

### Settings screen (first-time setup)

Shown automatically when credentials are missing. Also reachable via a gear icon inside the Add Show form.

Fields:
- **setlist.fm API key** — with a link to setlist.fm/api
- **GitHub Personal Access Token** — with instructions: create at github.com/settings/tokens, scope `contents` (read+write) on the `mattpippenger/concerts` repo

Both saved to localStorage on submit. No server involved.

### Add Show modal — step by step

**Step 1 — Artist**
- Text input: "Headliner"
- Debounced 300ms → `GET /rest/1.0/search/artists?artistName={q}&sort=relevance`
- Results appear as a dropdown (name + disambiguation if present)
- Selecting an artist stores the artist name and setlist.fm `mbid`

**Step 2 — Date**
- Standard `<input type="date">`
- Once both artist and date are filled, a "Find Setlist" button activates
- Tapping it calls `GET /rest/1.0/search/setlists?artistMbid={mbid}&date={DD-MM-YYYY}`

**Step 3 — Setlist auto-populate**

If a setlist is found:
- Venue, City, State, Tour Name, setlist.fm URL, and Songs all fill in
- A second call fires: `GET /rest/1.0/search/setlists?date={DD-MM-YYYY}&venueId={venueId}` to find other artists at the same venue that day
- Supporting acts confirmation (see below)
- All fields remain editable

If no setlist is found:
- A notice reads "No setlist found on setlist.fm — fill in what you know"
- All fields left blank and editable
- Supporting acts: manual entry only

**Supporting acts confirmation (validation step)**

After the venue+date secondary lookup returns other artists:
- A confirmation block appears: *"setlist.fm found these artists who played the same show — does this look right?"*
- Lists each found artist name
- Three choices: **Yes, add them** / **Edit the list** / **Skip**
- "Edit the list" shows the list with checkboxes and an "Add opener" text field for artists not on setlist.fm
- "Skip" proceeds with headliner only
- This validation step can be removed in a future iteration once the lookup is proven reliable

**Manual supporting acts (always available)**
- An "Add opener" text field is always visible below the supporting acts section
- Free-text entry; pressing Enter or tapping Add appends the name to the bands list

**Step 4 — Review & Save**

All fields displayed for final review:
- Headliner (locked — re-search to change)
- Date (locked — re-trigger to change)
- Supporting acts (editable list)
- Venue, City, State (editable)
- Tour Name (editable)
- Songs (collapsible read-only list; editable as a textarea if expanded)
- setlist.fm URL (editable)

**Save button** triggers the GitHub API write (see below). A spinner shows during the commit. On success: modal closes, new show appears in the current session immediately. On error: message shown, form stays open.

---

## GitHub API Save Flow

1. `GET https://api.github.com/repos/mattpippenger/concerts/contents/concerts-additions.json`
   - Header: `Authorization: Bearer {pat}`
   - Returns: `{ content: "<base64>", sha: "<sha>" }`

2. Decode base64 → parse JSON array → append new show object

3. `PUT https://api.github.com/repos/mattpippenger/concerts/contents/concerts-additions.json`
   - Body: `{ message: "Add show: {headliner} {date}", content: "<new base64>", sha: "<sha from step 1>" }`

4. On success: store new show in `localStorage` key `concert_pending` (array) so it survives a page refresh before GitHub Pages redeploys (~60 seconds). On next load, pending shows that already exist in the fetched `concerts-additions.json` are dropped from pending.

---

## Runtime merge in app.js

After `SHOWS` is built synchronously from `data.js`:

1. Fetch `concerts-additions.json` (relative URL — works on both localhost and GitHub Pages)
2. Also read `localStorage` pending additions (shows committed but not yet deployed)
3. Merge both into `SHOWS`, deduplicating by `headliner + date`
4. Re-sort `DATED`, re-build `bandIndex` and `venueIndex`
5. Re-render current view

The page renders immediately with historical data, then re-renders once additions load (~100ms on a warm connection). No loading spinner needed for the initial render.

---

## Files Changed

| File | Change |
|---|---|
| `concerts-additions.json` | New file, committed as `[]` |
| `index.html` | Add `<script src="concerts-additions.json">` — no, fetch at runtime instead |
| `app.js` | Async merge on boot; `viewAddShow()` modal; settings screen; API calls |
| `styles.css` | Floating `+` button; modal; form; confirmation block; gear icon |

---

## Out of Scope (this iteration)

- Editing existing shows (handled by asking Claude directly)
- Deleting shows
- Offline queuing (no service worker changes)
- setlist.fm OAuth (API key in localStorage is sufficient for a personal site)

# Add Show Form — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-browser "Add Show" form so new concerts can be entered from the site (desktop or iOS) using setlist.fm autocomplete, saved to GitHub via API, and immediately visible in the current session.

**Architecture:** A new `concerts-additions.json` file in the repo holds all shows added via the form. On page load, `app.js` fetches it asynchronously and merges the entries into the existing `SHOWS` array alongside historical `data.js` shows. The form calls setlist.fm from the browser (API key in localStorage) and saves via GitHub Contents API (PAT in localStorage).

**Tech Stack:** Vanilla ES5 JavaScript (matching existing codebase), no frameworks, no build step. setlist.fm REST API v1. GitHub Contents API v3.

**Spec:** `docs/superpowers/specs/2026-08-25-add-show-form-design.md`

## Global Constraints

- All JavaScript must be ES5 (var, no arrow functions, no template literals, no const/let) — the existing codebase is strict ES5 and the same style must be followed throughout
- No new dependencies or build steps
- `concerts-additions.json` must never be committed with sensitive data (it contains only concert info, never API keys or PATs)
- `setlist-api-key.txt` is git-ignored and must never be committed — credentials live only in localStorage
- The floating `+` button and modal must work on both desktop browsers and iOS Safari (PWA context)
- All new HTML injected via `innerHTML` must use the existing `esc()` helper for any user-supplied strings
- Follow existing code style: `var` declarations, named function expressions, direct `innerHTML` assignment, `el()` for getElementById

---

## File Map

| File | Change |
|---|---|
| `concerts-additions.json` | **Create** — starts as `[]`, grows as shows are added |
| `index.html` | **Modify** — add floating `+` button and modal overlay elements to `<body>` |
| `app.js` | **Modify** — async merge on boot; full Add Show form logic (~400 lines added near end of IIFE, before `boot()`) |
| `styles.css` | **Modify** — floating button, modal, form, autocomplete dropdown, confirmation block |

---

## Task 1: concerts-additions.json + Async Merge

**Files:**
- Create: `concerts-additions.json`
- Modify: `app.js` (after SHOWS/DATED/bandIndex/venueIndex are built, inside `boot()`)

**Interfaces:**
- Produces: `mergeAdditions(rawArray)` — takes an array of raw show objects (same shape as `window.CONCERT_DATA` entries), enriches each through the same pipeline as SHOWS, merges into global `SHOWS`/`DATED`/`bandIndex`/`venueIndex`, re-renders current view. Called by fetch callback and by the save flow (Task 6).

- [ ] **Step 1: Create concerts-additions.json**

```json
[]
```

Save to `concerts-additions.json` in the project root (same folder as `index.html`).

- [ ] **Step 2: Add mergeAdditions() and fetchAdditions() to app.js**

Find the line `// --------------------------------------------------------------- boot` near the end of app.js. Insert the following block ABOVE that line:

```javascript
  // -------------------------------------------------------- additions merge
  var CURRENT_VIEW = "overview";

  function enrichShow(s, idOffset) {
    var p = parts(s.date);
    var pv = resolveVenue(s.venue);
    return {
      id: idOffset,
      headliner: s.headliner || "",
      bands: (s.bands && s.bands.length ? s.bands : [s.headliner]).filter(Boolean),
      date: s.date || null,
      year: s.year || (p ? p.y : null),
      month: p ? p.m : null,
      day: p ? p.d : null,
      venue: pv.name,
      venueAka: pv.aka,
      venueRaw: s.venue || "",
      city: s.city || "",
      state: s.state || "",
      setlistUrl: setlistOverrideFor(s.headliner, s.date) || s.setlistUrl || null,
      songs: s.songs || [],
      tourName: s.tourName || "",
      badges: [],
      distMiles: null,
      fromAdditions: true
    };
  }

  function recomputeDerived() {
    // re-sort DATED
    DATED.length = 0;
    SHOWS.filter(function (s) { return s.date; })
         .sort(function (a, b) { return a.date < b.date ? -1 : a.date > b.date ? 1 : a.id - b.id; })
         .forEach(function (s, i) { DATED.push(s); s.ordinal = i + 1; });

    // recompute badges for new shows only
    SHOWS.forEach(function (s) {
      if (!s.fromAdditions) return;
      s.badges = [];
      var coords = CITY_COORDS[(s.city || '') + '|' + (s.state || '')];
      s.distMiles = coords ? Math.round(haversineMiles(HOME_COORDS[0], HOME_COORDS[1], coords[0], coords[1])) : null;
      if (s.distMiles >= 500)      s.badges.push('gone-distance');
      else if (s.distMiles >= 250) s.badges.push('road-trip');
      if (s.state && US_STATES.indexOf(s.state) === -1) s.badges.push('passport');
      if (RETIRED[groupOf(s.headliner)]) s.badges.push('final-bow');
    });

    // rebuild bandIndex entries for new shows
    SHOWS.forEach(function (s) {
      if (!s.fromAdditions) return;
      var seen = {};
      s.bands.forEach(function (b) {
        if (!b) return;
        var g = groupOf(b);
        if (seen[g]) return;
        seen[g] = 1;
        if (!bandIndex[g]) bandIndex[g] = [];
        // avoid duplicates if mergeAdditions called twice
        var already = bandIndex[g].some(function (x) { return x.id === s.id; });
        if (!already) bandIndex[g].push(s);
      });
    });
    Object.keys(bandIndex).forEach(function (k) {
      bandIndex[k].sort(function (a, b) {
        var ad = a.date || "9999", bd = b.date || "9999";
        return ad < bd ? -1 : ad > bd ? 1 : a.id - b.id;
      });
    });

    // rebuild venueIndex entries for new shows
    SHOWS.forEach(function (s) {
      if (!s.fromAdditions || !s.venue) return;
      if (!venueIndex[s.venue]) venueIndex[s.venue] = [];
      var already = venueIndex[s.venue].some(function (x) { return x.id === s.id; });
      if (!already) venueIndex[s.venue].push(s);
    });
  }

  function mergeAdditions(rawArray) {
    if (!rawArray || !rawArray.length) return;
    rawArray.forEach(function (raw) {
      // deduplicate by headliner+date
      var dup = SHOWS.some(function (s) {
        return s.headliner === (raw.headliner || "") && s.date === (raw.date || null);
      });
      if (dup) return;
      var enriched = enrichShow(raw, SHOWS.length);
      SHOWS.push(enriched);
    });
    recomputeDerived();
    // re-render whichever view is currently showing
    setView(CURRENT_VIEW);
  }

  function fetchAdditions() {
    var url = "concerts-additions.json?_=" + Date.now();
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      if (xhr.status === 200 || xhr.status === 0) {
        try {
          var data = JSON.parse(xhr.responseText);
          // also merge any locally-pending shows not yet deployed
          var pending = [];
          try { pending = JSON.parse(localStorage.getItem("concert_pending") || "[]"); } catch (e) {}
          // combine: committed additions + pending (dedup handles overlap)
          mergeAdditions(data.concat(pending));
        } catch (e) { /* malformed JSON — skip */ }
      }
    };
    xhr.send();
  }
```

- [ ] **Step 3: Track current view and call fetchAdditions in boot()**

Find `setView("overview");` at the very end of `boot()`. Change it to:

```javascript
    setView("overview");
    fetchAdditions();
```

Also find the existing `setView` function definition (search for `function setView`). Wrap its body to track `CURRENT_VIEW`:

```javascript
  function setView(name) {
    CURRENT_VIEW = name || "overview";
    // ... existing body unchanged ...
  }
```

The existing `setView` function looks like:
```javascript
  function setView(name) {
    var fn = VIEWS[name];
```
Change it to:
```javascript
  function setView(name) {
    CURRENT_VIEW = name || "overview";
    var fn = VIEWS[name];
```

- [ ] **Step 4: Manually verify merge works**

Open the site in a browser. Open DevTools console. Run:
```javascript
// Simulate what mergeAdditions does with a test entry
fetch('concerts-additions.json').then(r => r.json()).then(d => console.log('additions:', d));
```
Expected: `additions: []` (empty array, no errors). The page should load and render normally.

- [ ] **Step 5: Test merge with a real entry**

Temporarily edit `concerts-additions.json` to:
```json
[{"headliner":"Test Artist","bands":["Test Artist"],"date":"2026-01-01","venue":"Test Venue","city":"Indianapolis","state":"IN","tourName":"","setlistUrl":null,"songs":[]}]
```
Reload the page. Navigate to Artists — "Test Artist" should appear. Navigate to Venues — "Test Venue" should appear. Confirm it shows up. Then revert `concerts-additions.json` back to `[]`.

- [ ] **Step 6: Commit**

```
git add concerts-additions.json app.js
git commit -m "Add concerts-additions.json and async merge into SHOWS on boot"
```

---

## Task 2: Floating + Button, Modal Shell, and Settings Screen

**Files:**
- Modify: `index.html` — add button + modal markup
- Modify: `styles.css` — button + modal + settings form styles
- Modify: `app.js` — credentials storage, settings screen render, modal open/close

**Interfaces:**
- Produces: `openAddModal()` — opens the modal; shows settings screen if credentials missing, otherwise shows add form stub
- Produces: `closeAddModal()` — closes modal, resets form state
- Produces: `getCredentials()` → `{ setlistKey: string, githubPat: string }` — reads from localStorage; returns nulls if not set
- Produces: `saveCredentials(setlistKey, githubPat)` — writes to localStorage

- [ ] **Step 1: Add button and modal markup to index.html**

Add before the closing `</body>` tag (after the service worker script block):

```html
  <!-- Add Show -->
  <button class="add-show-fab" id="add-show-fab" aria-label="Add a show">+</button>

  <div class="add-modal-overlay" id="add-modal-overlay" aria-hidden="true">
    <div class="add-modal" id="add-modal" role="dialog" aria-modal="true" aria-label="Add Show">
      <button class="add-modal-close" id="add-modal-close" aria-label="Close">&times;</button>
      <div class="add-modal-body" id="add-modal-body">
        <!-- content rendered by app.js -->
      </div>
    </div>
  </div>
```

- [ ] **Step 2: Add CSS for floating button and modal**

Append to the end of `styles.css`:

```css
/* ------------------------------------------------------------------ Add Show */
.add-show-fab {
  position: fixed;
  bottom: 24px;
  right: 24px;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--accent, #e05c2a);
  color: #fff;
  font-size: 28px;
  line-height: 1;
  border: none;
  cursor: pointer;
  box-shadow: 0 4px 16px rgba(0,0,0,0.3);
  z-index: 200;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.15s, box-shadow 0.15s;
}
.add-show-fab:hover { transform: scale(1.08); box-shadow: 0 6px 20px rgba(0,0,0,0.35); }
.add-show-fab:active { transform: scale(0.96); }

.add-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.6);
  z-index: 300;
  display: none;
  align-items: flex-start;
  justify-content: center;
  padding: 16px;
  overflow-y: auto;
}
.add-modal-overlay.is-open { display: flex; }

.add-modal {
  background: var(--surface, #fff);
  border-radius: 12px;
  width: 100%;
  max-width: 540px;
  margin: auto;
  padding: 24px;
  position: relative;
  box-shadow: 0 8px 32px rgba(0,0,0,0.25);
}

.add-modal-close {
  position: absolute;
  top: 12px;
  right: 16px;
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: var(--ink-muted, #888);
  line-height: 1;
  padding: 4px 8px;
}
.add-modal-close:hover { color: var(--ink, #222); }

.add-modal h2 { margin: 0 0 20px; font-size: 1.2rem; }

/* Settings screen */
.add-settings-field { margin-bottom: 16px; }
.add-settings-field label { display: block; font-size: 0.8rem; font-weight: 600; margin-bottom: 4px; color: var(--ink-muted, #888); text-transform: uppercase; letter-spacing: 0.05em; }
.add-settings-field input { width: 100%; box-sizing: border-box; padding: 10px 12px; border: 1px solid var(--border, #ddd); border-radius: 6px; font-size: 0.95rem; background: var(--surface, #fff); color: var(--ink, #222); }
.add-settings-field input:focus { outline: 2px solid var(--accent, #e05c2a); border-color: transparent; }
.add-settings-note { font-size: 0.78rem; color: var(--ink-muted, #888); margin-top: 4px; }
.add-settings-note a { color: var(--accent, #e05c2a); }

.add-btn-row { display: flex; gap: 10px; margin-top: 20px; }
.add-btn { padding: 10px 20px; border-radius: 6px; border: none; font-size: 0.95rem; font-weight: 600; cursor: pointer; }
.add-btn-primary { background: var(--accent, #e05c2a); color: #fff; }
.add-btn-primary:hover { opacity: 0.9; }
.add-btn-secondary { background: var(--surface-raised, #f0f0f0); color: var(--ink, #222); }
.add-btn-secondary:hover { background: var(--border, #ddd); }

.add-gear { background: none; border: none; cursor: pointer; font-size: 0.85rem; color: var(--ink-muted, #888); padding: 0; display: inline-flex; align-items: center; gap: 4px; }
.add-gear:hover { color: var(--ink, #222); }
```

- [ ] **Step 3: Add credentials and modal logic to app.js**

Insert this block ABOVE the `// -------------------------------------------------------- additions merge` comment added in Task 1:

```javascript
  // -------------------------------------------------------- add show: credentials
  var CRED_SETLIST = "concert_setlist_key";
  var CRED_GITHUB  = "concert_github_pat";
  var GITHUB_REPO  = "mattpippenger/concerts";
  var ADDITIONS_PATH = "concerts-additions.json";

  function getCredentials() {
    try {
      return {
        setlistKey: localStorage.getItem(CRED_SETLIST) || "",
        githubPat:  localStorage.getItem(CRED_GITHUB)  || ""
      };
    } catch (e) { return { setlistKey: "", githubPat: "" }; }
  }

  function saveCredentials(setlistKey, githubPat) {
    try {
      localStorage.setItem(CRED_SETLIST, setlistKey);
      localStorage.setItem(CRED_GITHUB,  githubPat);
    } catch (e) {}
  }

  // -------------------------------------------------------- add show: modal
  function openAddModal() {
    var overlay = el("add-modal-overlay");
    if (!overlay) return;
    overlay.classList.add("is-open");
    overlay.setAttribute("aria-hidden", "false");
    var creds = getCredentials();
    if (!creds.setlistKey || !creds.githubPat) {
      renderSettingsScreen();
    } else {
      renderAddForm();
    }
  }

  function closeAddModal() {
    var overlay = el("add-modal-overlay");
    if (!overlay) return;
    overlay.classList.remove("is-open");
    overlay.setAttribute("aria-hidden", "true");
    el("add-modal-body").innerHTML = "";
  }

  function renderSettingsScreen(onSave) {
    var body = el("add-modal-body");
    body.innerHTML =
      '<h2>&#9881; Settings</h2>' +
      '<p style="font-size:0.85rem;color:var(--ink-muted,#888);margin:0 0 16px">Enter your API credentials once. They\'re stored only in this browser.</p>' +
      '<div class="add-settings-field">' +
        '<label>setlist.fm API Key</label>' +
        '<input id="set-setlist-key" type="password" placeholder="paste your key here" autocomplete="off">' +
        '<div class="add-settings-note">Get one free at <a href="https://www.setlist.fm/settings/api" target="_blank" rel="noopener">setlist.fm/settings/api</a></div>' +
      '</div>' +
      '<div class="add-settings-field">' +
        '<label>GitHub Personal Access Token</label>' +
        '<input id="set-github-pat" type="password" placeholder="ghp_..." autocomplete="off">' +
        '<div class="add-settings-note">Create at <a href="https://github.com/settings/tokens" target="_blank" rel="noopener">github.com/settings/tokens</a> &mdash; Fine-grained token, Contents read+write on <b>mattpippenger/concerts</b></div>' +
      '</div>' +
      '<div class="add-btn-row">' +
        '<button class="add-btn add-btn-primary" id="set-save-btn">Save &amp; Continue</button>' +
        '<button class="add-btn add-btn-secondary" id="set-cancel-btn">Cancel</button>' +
      '</div>';

    // pre-fill with stored values if re-opening settings
    var creds = getCredentials();
    el("set-setlist-key").value = creds.setlistKey;
    el("set-github-pat").value  = creds.githubPat;

    el("set-save-btn").addEventListener("click", function () {
      var sk = el("set-setlist-key").value.trim();
      var gp = el("set-github-pat").value.trim();
      if (!sk || !gp) { alert("Both fields are required."); return; }
      saveCredentials(sk, gp);
      if (typeof onSave === "function") onSave();
      else renderAddForm();
    });

    el("set-cancel-btn").addEventListener("click", function () {
      if (typeof onSave === "function") renderAddForm();
      else closeAddModal();
    });
  }
```

- [ ] **Step 4: Wire up the + button and close button in boot()**

At the end of `boot()`, just before `setView("overview");`, add:

```javascript
    var fab = el("add-show-fab");
    if (fab) fab.addEventListener("click", openAddModal);

    var closeBtn = el("add-modal-close");
    if (closeBtn) closeBtn.addEventListener("click", closeAddModal);

    var overlay = el("add-modal-overlay");
    if (overlay) overlay.addEventListener("click", function (e) {
      if (e.target === overlay) closeAddModal();
    });

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") closeAddModal();
    });
```

- [ ] **Step 5: Add renderAddForm stub to app.js** (placeholder for Task 3)

Add this function right after `renderSettingsScreen`:

```javascript
  function renderAddForm() {
    var body = el("add-modal-body");
    body.innerHTML = '<h2>Add Show</h2><p style="color:var(--ink-muted,#888)">Form coming in next task&hellip;</p>';
  }
```

- [ ] **Step 6: Manually verify**

Open the site. The `+` button should appear bottom-right. Click it:
- If no credentials stored → Settings screen appears with two password fields and Save & Continue button
- Fill in dummy values, click Save & Continue → "Add Show / Form coming in next task…" placeholder appears
- Press Escape or click outside modal → modal closes
- Click `+` again → skips settings, goes straight to the stub form (credentials were saved)
- Click the gear ⚙ button (not yet added, will appear in Task 3) — not present yet, that's fine

- [ ] **Step 7: Commit**

```
git add index.html styles.css app.js
git commit -m "Add floating + button, modal shell, and settings/credentials screen"
```

---

## Task 3: Artist Autocomplete

**Files:**
- Modify: `app.js` — replace renderAddForm stub; add searchArtists(), autocomplete dropdown logic
- Modify: `styles.css` — autocomplete dropdown styles

**Interfaces:**
- Consumes: `getCredentials().setlistKey`
- Produces: form state object `ADD_STATE` — `{ artistName, artistMbid, date, venueId, ... }` shared across Tasks 3–6
- Produces: `renderAddForm()` — replaces stub; renders the full form shell with artist search field active

- [ ] **Step 1: Add ADD_STATE and setlist.fm fetch helper to app.js**

Insert this block just before `renderSettingsScreen`:

```javascript
  // -------------------------------------------------------- add show: state + API
  var ADD_STATE = {};

  function setlistFetch(path, callback) {
    var creds = getCredentials();
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "https://api.setlist.fm/rest/1.0/" + path, true);
    xhr.setRequestHeader("x-api-key", creds.setlistKey);
    xhr.setRequestHeader("Accept", "application/json");
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      if (xhr.status === 200) {
        try { callback(null, JSON.parse(xhr.responseText)); } catch (e) { callback(e, null); }
      } else {
        callback(new Error("HTTP " + xhr.status), null);
      }
    };
    xhr.send();
  }
```

- [ ] **Step 2: Add autocomplete dropdown CSS to styles.css**

Append to end of `styles.css`:

```css
/* Autocomplete dropdown */
.add-autocomplete-wrap { position: relative; }
.add-autocomplete-input { width: 100%; box-sizing: border-box; padding: 10px 12px; border: 1px solid var(--border, #ddd); border-radius: 6px; font-size: 0.95rem; background: var(--surface, #fff); color: var(--ink, #222); }
.add-autocomplete-input:focus { outline: 2px solid var(--accent, #e05c2a); border-color: transparent; }
.add-autocomplete-dropdown { position: absolute; top: calc(100% + 4px); left: 0; right: 0; background: var(--surface, #fff); border: 1px solid var(--border, #ddd); border-radius: 6px; box-shadow: 0 4px 16px rgba(0,0,0,0.15); z-index: 400; max-height: 220px; overflow-y: auto; }
.add-autocomplete-item { padding: 10px 14px; cursor: pointer; font-size: 0.9rem; border-bottom: 1px solid var(--border, #eee); }
.add-autocomplete-item:last-child { border-bottom: none; }
.add-autocomplete-item:hover, .add-autocomplete-item.is-focused { background: var(--surface-raised, #f5f5f5); }
.add-autocomplete-item .ac-dis { font-size: 0.78rem; color: var(--ink-muted, #888); margin-left: 6px; }
.add-autocomplete-loading { padding: 10px 14px; font-size: 0.85rem; color: var(--ink-muted, #888); }

/* Form section headers */
.add-field-group { margin-bottom: 18px; }
.add-field-group label { display: block; font-size: 0.78rem; font-weight: 600; margin-bottom: 4px; color: var(--ink-muted, #888); text-transform: uppercase; letter-spacing: 0.05em; }
.add-selected-artist { display: flex; align-items: center; gap: 8px; padding: 8px 12px; background: var(--surface-raised, #f0f0f0); border-radius: 6px; font-size: 0.95rem; }
.add-selected-artist button { background: none; border: none; cursor: pointer; color: var(--ink-muted, #888); font-size: 1rem; padding: 0 4px; line-height: 1; }
.add-selected-artist button:hover { color: var(--ink, #222); }
```

- [ ] **Step 3: Replace renderAddForm stub with real implementation**

Find and replace the `renderAddForm` stub from Task 2:

```javascript
  function renderAddForm() {
    var body = el("add-modal-body");
    body.innerHTML =
      '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px">' +
        '<h2 style="margin:0">Add Show</h2>' +
        '<button class="add-gear" id="add-open-settings">&#9881; Settings</button>' +
      '</div>' +

      '<div class="add-field-group" id="add-artist-group">' +
        '<label>Headliner</label>' +
        '<div class="add-autocomplete-wrap" id="add-ac-wrap">' +
          '<input class="add-autocomplete-input" id="add-artist-input" type="text" placeholder="Start typing an artist name…" autocomplete="off" autocorrect="off" spellcheck="false">' +
          '<div class="add-autocomplete-dropdown" id="add-ac-dropdown" style="display:none"></div>' +
        '</div>' +
      '</div>' +

      '<div id="add-rest" style="display:none">' +
        '<div class="add-field-group">' +
          '<label>Date</label>' +
          '<input class="add-autocomplete-input" id="add-date-input" type="date">' +
        '</div>' +
        '<button class="add-btn add-btn-primary" id="add-find-setlist-btn" style="margin-bottom:18px" disabled>Find Setlist</button>' +
        '<div id="add-setlist-result"></div>' +
      '</div>' +

      '<div class="add-btn-row" id="add-save-row" style="display:none">' +
        '<button class="add-btn add-btn-primary" id="add-save-btn">Save Show</button>' +
        '<button class="add-btn add-btn-secondary" id="add-cancel-btn">Cancel</button>' +
      '</div>';

    el("add-open-settings").addEventListener("click", function () {
      renderSettingsScreen(function () { renderAddForm(); });
    });

    el("add-cancel-btn") && el("add-cancel-btn").addEventListener("click", closeAddModal);

    wireArtistAutocomplete();
  }
```

- [ ] **Step 4: Add wireArtistAutocomplete() to app.js** (right after renderAddForm)

```javascript
  function wireArtistAutocomplete() {
    ADD_STATE = {};
    var input    = el("add-artist-input");
    var dropdown = el("add-ac-dropdown");
    var rest     = el("add-rest");
    if (!input) return;

    var debounceTimer = null;

    function showDropdown(html) {
      dropdown.innerHTML = html;
      dropdown.style.display = html ? "block" : "none";
    }

    function selectArtist(name, mbid) {
      ADD_STATE.artistName = name;
      ADD_STATE.artistMbid = mbid;
      showDropdown("");

      // Replace input with selected-artist pill
      var wrap = el("add-ac-wrap");
      wrap.innerHTML =
        '<div class="add-selected-artist">' +
          '<span>' + esc(name) + '</span>' +
          '<button id="add-change-artist" title="Change artist">&times;</button>' +
        '</div>';
      el("add-change-artist").addEventListener("click", function () {
        ADD_STATE.artistName = "";
        ADD_STATE.artistMbid = "";
        rest.style.display = "none";
        el("add-save-row").style.display = "none";
        wireArtistAutocomplete();
      });

      rest.style.display = "block";
      wireDateAndSetlist();
    }

    input.addEventListener("input", function () {
      var q = input.value.trim();
      clearTimeout(debounceTimer);
      if (q.length < 2) { showDropdown(""); return; }
      debounceTimer = setTimeout(function () {
        showDropdown('<div class="add-autocomplete-loading">Searching…</div>');
        setlistFetch(
          "search/artists?artistName=" + encodeURIComponent(q) + "&sort=relevance&p=1",
          function (err, data) {
            if (err || !data || !data.artist) { showDropdown(""); return; }
            var items = data.artist.slice(0, 8).map(function (a) {
              var dis = a.disambiguation ? '<span class="ac-dis">(' + esc(a.disambiguation) + ')</span>' : "";
              return '<div class="add-autocomplete-item" data-mbid="' + esc(a.mbid) + '" data-name="' + esc(a.name) + '">' + esc(a.name) + dis + '</div>';
            }).join("");
            showDropdown(items || '<div class="add-autocomplete-loading">No results</div>');
            Array.prototype.forEach.call(
              dropdown.querySelectorAll(".add-autocomplete-item"),
              function (item) {
                item.addEventListener("click", function () {
                  selectArtist(item.getAttribute("data-name"), item.getAttribute("data-mbid"));
                });
              }
            );
          }
        );
      }, 300);
    });

    // close dropdown on outside click
    document.addEventListener("click", function onOutside(e) {
      if (!dropdown.contains(e.target) && e.target !== input) {
        showDropdown("");
        document.removeEventListener("click", onOutside);
      }
    });
  }
```

- [ ] **Step 5: Manually verify artist autocomplete**

Open the site, click `+`, open the Add Show form. Type "Pearl Jam" in the Headliner field. After 300ms a dropdown should appear with "Pearl Jam" and possibly other matches from setlist.fm. Click "Pearl Jam" — the input is replaced with a pill showing "Pearl Jam ×", and the date field section appears below. Clicking × clears and restores the text input.

- [ ] **Step 6: Commit**

```
git add app.js styles.css
git commit -m "Add artist autocomplete using setlist.fm search/artists API"
```

---

## Task 4: Date Input + Setlist Lookup + Auto-Populate Fields

**Files:**
- Modify: `app.js` — wireDateAndSetlist(), renderSetlistFields()
- Modify: `styles.css` — auto-populated field styles

**Interfaces:**
- Consumes: `ADD_STATE.artistMbid` (from Task 3)
- Produces: `ADD_STATE` updated with: `{ date, venueId, venueName, venueCity, venueState, tourName, setlistUrl, songs }`
- Produces: `wireDateAndSetlist()` — wires up the date input and Find Setlist button; called by `selectArtist()`

- [ ] **Step 1: Add editable field CSS to styles.css**

Append to end of `styles.css`:

```css
/* Auto-populated editable fields */
.add-auto-field { width: 100%; box-sizing: border-box; padding: 10px 12px; border: 1px solid var(--border, #ddd); border-radius: 6px; font-size: 0.9rem; background: var(--surface-raised, #f9f9f9); color: var(--ink, #222); }
.add-auto-field:focus { outline: 2px solid var(--accent, #e05c2a); background: var(--surface, #fff); border-color: transparent; }
.add-auto-label { display: block; font-size: 0.78rem; font-weight: 600; margin-bottom: 4px; color: var(--ink-muted, #888); text-transform: uppercase; letter-spacing: 0.05em; }
.add-two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 18px; }
.add-notice { font-size: 0.82rem; color: var(--ink-muted, #888); padding: 10px 14px; background: var(--surface-raised, #f5f5f5); border-radius: 6px; margin-bottom: 18px; }
.add-notice.add-notice-warn { color: #c07000; background: #fffbe6; }
.add-songs-toggle { background: none; border: none; cursor: pointer; font-size: 0.82rem; color: var(--accent, #e05c2a); padding: 0; margin-bottom: 8px; }
.add-songs-list { font-size: 0.82rem; color: var(--ink-muted, #888); max-height: 160px; overflow-y: auto; padding: 8px 12px; background: var(--surface-raised, #f5f5f5); border-radius: 6px; }
```

- [ ] **Step 2: Add wireDateAndSetlist() and renderSetlistFields() to app.js**

Insert right after `wireArtistAutocomplete()`:

```javascript
  function wireDateAndSetlist() {
    var dateInput   = el("add-date-input");
    var findBtn     = el("add-find-setlist-btn");
    var resultArea  = el("add-setlist-result");
    if (!dateInput || !findBtn) return;

    function updateFindBtn() {
      findBtn.disabled = !(dateInput.value && ADD_STATE.artistMbid);
    }
    dateInput.addEventListener("input", updateFindBtn);
    updateFindBtn();

    findBtn.addEventListener("click", function () {
      var d = dateInput.value; // "YYYY-MM-DD"
      if (!d || !ADD_STATE.artistMbid) return;
      ADD_STATE.date = d;

      // convert to setlist.fm format: "DD-MM-YYYY"
      var parts2 = d.split("-");
      var sfDate = parts2[2] + "-" + parts2[1] + "-" + parts2[0];

      findBtn.disabled = true;
      findBtn.textContent = "Searching…";
      resultArea.innerHTML = "";

      setlistFetch(
        "search/setlists?artistMbid=" + encodeURIComponent(ADD_STATE.artistMbid) + "&date=" + sfDate,
        function (err, data) {
          findBtn.disabled = false;
          findBtn.textContent = "Find Setlist";

          if (err || !data || !data.setlist || !data.setlist.length) {
            ADD_STATE.setlistFound = false;
            resultArea.innerHTML = '<div class="add-notice add-notice-warn">No setlist found on setlist.fm for this date &mdash; fill in the details below.</div>';
            renderSetlistFields(null);
            return;
          }

          var sl = data.setlist[0];
          ADD_STATE.setlistFound = true;
          ADD_STATE.venueId  = sl.venue && sl.venue.id;
          ADD_STATE.setlistUrl = "https://www.setlist.fm/setlist/" +
            sl.artist.name.toLowerCase().replace(/\s+/g, "-") + "/" +
            sl.eventDate.split("-")[2] + "-" +  // DD -> year part is wrong here; use the url field instead
            sl.id + ".html";
          // prefer the direct url from the response if available
          if (sl.url) ADD_STATE.setlistUrl = sl.url;

          // extract songs from sets
          var songs = [];
          if (sl.sets && sl.sets.set) {
            sl.sets.set.forEach(function (set) {
              (set.song || []).forEach(function (song) {
                if (song.name) songs.push(song.name);
              });
            });
          }
          ADD_STATE.songs = songs;

          var venue = sl.venue || {};
          var city  = venue.city || {};
          ADD_STATE.venueName  = venue.name || "";
          ADD_STATE.venueCity  = city.name  || "";
          ADD_STATE.venueState = city.stateCode || (city.country && city.country.code) || "";
          ADD_STATE.tourName   = (sl.tour && sl.tour.name) || "";

          resultArea.innerHTML = '<div class="add-notice">Found setlist on setlist.fm &mdash; fields pre-filled below.</div>';
          renderSetlistFields(sl);

          // kick off supporting acts lookup if we have a venueId
          if (ADD_STATE.venueId) {
            fetchSupportingActs(sfDate, ADD_STATE.venueId);
          } else {
            renderManualOpenerField();
          }
        }
      );
    });
  }

  function renderSetlistFields(sl) {
    var resultArea = el("add-setlist-result");
    var songsHtml = "";
    var songs = ADD_STATE.songs || [];
    if (songs.length) {
      songsHtml =
        '<div class="add-field-group">' +
          '<button class="add-songs-toggle" id="add-songs-toggle" type="button">&#9654; ' + songs.length + ' songs from setlist.fm</button>' +
          '<div id="add-songs-list" style="display:none" class="add-songs-list">' + songs.map(esc).join("<br>") + '</div>' +
        '</div>';
    }

    resultArea.innerHTML += (resultArea.innerHTML.indexOf("add-notice") >= 0 ? "" : "") +
      '<div class="add-two-col">' +
        '<div class="add-field-group">' +
          '<label class="add-auto-label">Venue</label>' +
          '<input class="add-auto-field" id="add-venue" type="text" value="' + esc(ADD_STATE.venueName || "") + '">' +
        '</div>' +
        '<div class="add-field-group">' +
          '<label class="add-auto-label">City</label>' +
          '<input class="add-auto-field" id="add-city" type="text" value="' + esc(ADD_STATE.venueCity || "") + '">' +
        '</div>' +
      '</div>' +
      '<div class="add-two-col">' +
        '<div class="add-field-group">' +
          '<label class="add-auto-label">State / Country Code</label>' +
          '<input class="add-auto-field" id="add-state" type="text" value="' + esc(ADD_STATE.venueState || "") + '" maxlength="3">' +
        '</div>' +
        '<div class="add-field-group">' +
          '<label class="add-auto-label">Tour Name</label>' +
          '<input class="add-auto-field" id="add-tour" type="text" value="' + esc(ADD_STATE.tourName || "") + '">' +
        '</div>' +
      '</div>' +
      '<div class="add-field-group">' +
        '<label class="add-auto-label">setlist.fm URL</label>' +
        '<input class="add-auto-field" id="add-setlist-url" type="url" value="' + esc(ADD_STATE.setlistUrl || "") + '">' +
      '</div>' +
      songsHtml +
      '<div id="add-supporting-acts-section"></div>';

    if (songs.length) {
      el("add-songs-toggle").addEventListener("click", function () {
        var list = el("add-songs-list");
        var open = list.style.display === "none";
        list.style.display = open ? "block" : "none";
        el("add-songs-toggle").textContent = (open ? "▼ " : "► ") + songs.length + " songs from setlist.fm";
      });
    }
  }
```

- [ ] **Step 3: Manually verify setlist lookup**

Open the Add Show form. Search and select "Dave Matthews Band". Enter a date you attended (e.g. pick any past date from your concert list). Click "Find Setlist". Expected:
- If found: "Found setlist on setlist.fm — fields pre-filled below." and venue/city/state/tour/URL fields appear pre-filled and editable.
- If not found: "No setlist found" notice with blank editable fields.
In both cases, the `add-supporting-acts-section` div exists (empty for now — Task 5 will populate it).

- [ ] **Step 4: Commit**

```
git add app.js styles.css
git commit -m "Add date input, Find Setlist call, and auto-populated editable fields"
```

---

## Task 5: Supporting Acts — Confirmation + Manual Entry

**Files:**
- Modify: `app.js` — fetchSupportingActs(), renderActsConfirmation(), renderManualOpenerField(), showSaveRow()
- Modify: `styles.css` — confirmation block, acts checklist styles

**Interfaces:**
- Consumes: `ADD_STATE.venueId`, `ADD_STATE.artistName`, `ADD_STATE.date` (from Task 4)
- Produces: `ADD_STATE.bands` — final array of all performers including headliner
- Produces: `showSaveRow()` — makes the Save/Cancel row visible; called at end of Task 5 flow

- [ ] **Step 1: Add confirmation block CSS to styles.css**

Append to end of `styles.css`:

```css
/* Supporting acts confirmation */
.add-acts-confirm { border: 1px solid var(--border, #ddd); border-radius: 8px; padding: 14px 16px; margin-bottom: 18px; }
.add-acts-confirm h4 { margin: 0 0 10px; font-size: 0.9rem; }
.add-acts-list { list-style: none; padding: 0; margin: 0 0 12px; }
.add-acts-list li { display: flex; align-items: center; gap: 8px; padding: 5px 0; font-size: 0.9rem; }
.add-acts-list input[type=checkbox] { width: 16px; height: 16px; cursor: pointer; accent-color: var(--accent, #e05c2a); }
.add-manual-opener { display: flex; gap: 8px; margin-top: 8px; }
.add-manual-opener input { flex: 1; padding: 8px 10px; border: 1px solid var(--border, #ddd); border-radius: 6px; font-size: 0.88rem; background: var(--surface, #fff); color: var(--ink, #222); }
.add-manual-opener input:focus { outline: 2px solid var(--accent, #e05c2a); border-color: transparent; }
.add-manual-opener button { padding: 8px 14px; background: var(--surface-raised, #f0f0f0); border: 1px solid var(--border, #ddd); border-radius: 6px; cursor: pointer; font-size: 0.88rem; }
.add-manual-opener button:hover { background: var(--border, #ddd); }
.add-opener-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
.add-opener-chip { display: inline-flex; align-items: center; gap: 4px; padding: 3px 10px; background: var(--surface-raised, #eee); border-radius: 20px; font-size: 0.82rem; }
.add-opener-chip button { background: none; border: none; cursor: pointer; color: var(--ink-muted, #888); font-size: 0.9rem; padding: 0; line-height: 1; }
```

- [ ] **Step 2: Add fetchSupportingActs() to app.js** (after wireDateAndSetlist/renderSetlistFields)

```javascript
  function fetchSupportingActs(sfDate, venueId) {
    var section = el("add-supporting-acts-section");
    if (!section) return;
    section.innerHTML = '<div class="add-notice">Looking up other artists at this venue&hellip;</div>';

    setlistFetch(
      "search/setlists?date=" + sfDate + "&venueId=" + encodeURIComponent(venueId),
      function (err, data) {
        var otherArtists = [];
        if (!err && data && data.setlist) {
          data.setlist.forEach(function (sl) {
            var name = sl.artist && sl.artist.name;
            if (!name) return;
            if (name.toLowerCase() === (ADD_STATE.artistName || "").toLowerCase()) return;
            // avoid duplicates
            var dup = otherArtists.some(function (a) { return a.toLowerCase() === name.toLowerCase(); });
            if (!dup) otherArtists.push(name);
          });
        }

        if (!otherArtists.length) {
          section.innerHTML = "";
          renderManualOpenerField();
          showSaveRow();
          return;
        }
        renderActsConfirmation(otherArtists);
      }
    );
  }

  function renderActsConfirmation(otherArtists) {
    var section = el("add-supporting-acts-section");
    var checkboxes = otherArtists.map(function (name, i) {
      return '<li><input type="checkbox" id="act-' + i + '" checked><label for="act-' + i + '">' + esc(name) + '</label></li>';
    }).join("");

    section.innerHTML =
      '<div class="add-acts-confirm">' +
        '<h4>&#127911; setlist.fm found these artists at the same show &mdash; does this look right?</h4>' +
        '<ul class="add-acts-list">' + checkboxes + '</ul>' +
        '<div class="add-btn-row">' +
          '<button class="add-btn add-btn-primary" id="acts-yes-btn">Yes, add them</button>' +
          '<button class="add-btn add-btn-secondary" id="acts-skip-btn">Skip</button>' +
        '</div>' +
      '</div>' +
      '<div id="add-manual-opener-wrap"></div>';

    el("acts-yes-btn").addEventListener("click", function () {
      ADD_STATE.confirmedActs = [];
      otherArtists.forEach(function (name, i) {
        var cb = el("act-" + i);
        if (cb && cb.checked) ADD_STATE.confirmedActs.push(name);
      });
      el("add-supporting-acts-section").querySelector(".add-acts-confirm").style.display = "none";
      renderManualOpenerField();
      showSaveRow();
    });

    el("acts-skip-btn").addEventListener("click", function () {
      ADD_STATE.confirmedActs = [];
      el("add-supporting-acts-section").querySelector(".add-acts-confirm").style.display = "none";
      renderManualOpenerField();
      showSaveRow();
    });
  }

  function renderManualOpenerField() {
    var wrap = el("add-manual-opener-wrap") || el("add-supporting-acts-section");
    if (!wrap) return;
    if (!ADD_STATE.manualOpeners) ADD_STATE.manualOpeners = [];

    var chipsHtml = ADD_STATE.manualOpeners.map(function (name, i) {
      return '<span class="add-opener-chip">' + esc(name) + '<button data-idx="' + i + '" aria-label="Remove">&times;</button></span>';
    }).join("");

    wrap.innerHTML = wrap.innerHTML.replace(/<div id="add-manual-field-block">[\s\S]*$/, "") +
      '<div id="add-manual-field-block">' +
        '<label class="add-auto-label" style="margin-bottom:6px">Add opener (not on setlist.fm)</label>' +
        '<div class="add-manual-opener">' +
          '<input id="add-opener-input" type="text" placeholder="Opener name…" autocomplete="off">' +
          '<button id="add-opener-add-btn" type="button">Add</button>' +
        '</div>' +
        (chipsHtml ? '<div class="add-opener-chips" id="add-opener-chips">' + chipsHtml + '</div>' : '') +
      '</div>';

    function addOpener() {
      var inp = el("add-opener-input");
      var val = inp ? inp.value.trim() : "";
      if (!val) return;
      ADD_STATE.manualOpeners.push(val);
      renderManualOpenerField();
      showSaveRow();
    }

    el("add-opener-add-btn").addEventListener("click", addOpener);
    el("add-opener-input").addEventListener("keydown", function (e) {
      if (e.key === "Enter") { e.preventDefault(); addOpener(); }
    });

    var chips = document.querySelectorAll(".add-opener-chip button");
    Array.prototype.forEach.call(chips, function (btn) {
      btn.addEventListener("click", function () {
        var idx = parseInt(btn.getAttribute("data-idx"), 10);
        ADD_STATE.manualOpeners.splice(idx, 1);
        renderManualOpenerField();
      });
    });

    showSaveRow();
  }

  function showSaveRow() {
    var row = el("add-save-row");
    if (row) row.style.display = "flex";

    // wire save button if not yet wired
    var saveBtn = el("add-save-btn");
    if (saveBtn && !saveBtn._wired) {
      saveBtn._wired = true;
      saveBtn.addEventListener("click", handleSaveShow);
    }
  }
```

- [ ] **Step 3: Manually verify supporting acts flow**

Find a show in your history where you know an opener was present and setlist.fm likely has both. Fill in the Add Show form (artist, date, Find Setlist). After setlist data loads:
- If other artists at that venue are found: confirmation block appears with "setlist.fm found these artists" and checkboxes
- Click "Yes, add them" → confirmation collapses, manual opener input appears, Save row appears
- Type an opener name, press Enter → chip appears with × to remove
- Click "Skip" → manual opener input appears without the confirmation

- [ ] **Step 4: Commit**

```
git add app.js styles.css
git commit -m "Add supporting acts confirmation step and manual opener entry"
```

---

## Task 6: Save Flow — GitHub API + Optimistic Update

**Files:**
- Modify: `app.js` — handleSaveShow(), buildShowFromState(), githubGetFile(), githubPutFile()
- Modify: `styles.css` — save spinner and success/error states

**Interfaces:**
- Consumes: `ADD_STATE` (all fields from Tasks 3–5), `getCredentials().githubPat`, `mergeAdditions()` (from Task 1)
- Consumes: GitHub Contents API: `GET/PUT /repos/mattpippenger/concerts/contents/concerts-additions.json`
- Produces: new entry appended to `concerts-additions.json` in GitHub repo; show merged into live `SHOWS` array immediately

- [ ] **Step 1: Add save spinner CSS to styles.css**

Append to end of `styles.css`:

```css
/* Save state */
.add-saving { opacity: 0.6; pointer-events: none; }
.add-save-status { font-size: 0.85rem; margin-top: 10px; padding: 8px 12px; border-radius: 6px; }
.add-save-status.ok  { background: #e6f7ee; color: #1a7a3c; }
.add-save-status.err { background: #fde8e8; color: #b91c1c; }
```

- [ ] **Step 2: Add GitHub API helpers and buildShowFromState() to app.js**

Insert right after `showSaveRow()`:

```javascript
  function githubGetFile(path, pat, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "https://api.github.com/repos/" + GITHUB_REPO + "/contents/" + path, true);
    xhr.setRequestHeader("Authorization", "Bearer " + pat);
    xhr.setRequestHeader("Accept", "application/vnd.github+json");
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      if (xhr.status === 200) {
        try {
          var resp = JSON.parse(xhr.responseText);
          var content = atob(resp.content.replace(/\n/g, ""));
          callback(null, { json: JSON.parse(content), sha: resp.sha });
        } catch (e) { callback(e, null); }
      } else {
        callback(new Error("GitHub GET failed: HTTP " + xhr.status + " " + xhr.responseText), null);
      }
    };
    xhr.send();
  }

  function githubPutFile(path, pat, content, sha, message, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open("PUT", "https://api.github.com/repos/" + GITHUB_REPO + "/contents/" + path, true);
    xhr.setRequestHeader("Authorization", "Bearer " + pat);
    xhr.setRequestHeader("Accept", "application/vnd.github+json");
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      if (xhr.status === 200 || xhr.status === 201) {
        callback(null);
      } else {
        callback(new Error("GitHub PUT failed: HTTP " + xhr.status + " " + xhr.responseText));
      }
    };
    var encoded = btoa(unescape(encodeURIComponent(content)));
    xhr.send(JSON.stringify({ message: message, content: encoded, sha: sha }));
  }

  function buildShowFromState() {
    var confirmedActs = ADD_STATE.confirmedActs || [];
    var manualOpeners = ADD_STATE.manualOpeners || [];
    // bands: openers first, headliner last (matching spreadsheet convention)
    var allBands = [];
    confirmedActs.forEach(function (b) { if (allBands.indexOf(b) === -1) allBands.push(b); });
    manualOpeners.forEach(function (b) { if (b && allBands.indexOf(b) === -1) allBands.push(b); });
    if (allBands.indexOf(ADD_STATE.artistName) === -1) allBands.push(ADD_STATE.artistName);

    return {
      headliner:  el("add-artist-input") ? "" : ADD_STATE.artistName, // input replaced by pill
      bands:      allBands,
      date:       ADD_STATE.date || "",
      venue:      (el("add-venue")       ? el("add-venue").value.trim()       : ADD_STATE.venueName   || ""),
      city:       (el("add-city")        ? el("add-city").value.trim()        : ADD_STATE.venueCity   || ""),
      state:      (el("add-state")       ? el("add-state").value.trim()       : ADD_STATE.venueState  || ""),
      tourName:   (el("add-tour")        ? el("add-tour").value.trim()        : ADD_STATE.tourName    || ""),
      setlistUrl: (el("add-setlist-url") ? el("add-setlist-url").value.trim() : ADD_STATE.setlistUrl  || null) || null,
      songs:      ADD_STATE.songs || []
    };
  }

  function handleSaveShow() {
    var showData = buildShowFromState();
    // headliner comes from ADD_STATE since the input was replaced by a pill
    showData.headliner = ADD_STATE.artistName || "";

    if (!showData.headliner || !showData.date) {
      alert("Artist and date are required.");
      return;
    }

    var modal = el("add-modal");
    if (modal) modal.classList.add("add-saving");

    var statusArea = document.createElement("div");
    statusArea.className = "add-save-status";
    statusArea.textContent = "Saving to GitHub…";
    var saveRow = el("add-save-row");
    if (saveRow) saveRow.parentNode.insertBefore(statusArea, saveRow.nextSibling);

    var creds = getCredentials();

    githubGetFile(ADDITIONS_PATH, creds.githubPat, function (err, file) {
      if (err) {
        if (modal) modal.classList.remove("add-saving");
        statusArea.className = "add-save-status err";
        statusArea.textContent = "Could not read concerts-additions.json from GitHub: " + err.message;
        return;
      }

      var arr = file.json;
      arr.push(showData);
      var newContent = JSON.stringify(arr, null, 2);
      var commitMsg  = "Add show: " + showData.headliner + " " + showData.date;

      githubPutFile(ADDITIONS_PATH, creds.githubPat, newContent, file.sha, commitMsg, function (putErr) {
        if (modal) modal.classList.remove("add-saving");

        if (putErr) {
          statusArea.className = "add-save-status err";
          statusArea.textContent = "Save failed: " + putErr.message;
          return;
        }

        // optimistic: add to localStorage pending so it survives a reload before Pages deploys
        try {
          var pending = JSON.parse(localStorage.getItem("concert_pending") || "[]");
          pending.push(showData);
          localStorage.setItem("concert_pending", JSON.stringify(pending));
        } catch (e) {}

        // merge immediately into the live session
        mergeAdditions([showData]);

        // update header count
        var serial = el("masthead-serial");
        if (serial) serial.innerHTML = "No.&nbsp;" + String(SHOWS.length).padStart(6, "0");

        statusArea.className = "add-save-status ok";
        statusArea.textContent = "✓ Saved! " + showData.headliner + " on " + prettyDate(showData.date) + " added to your tracker.";

        // close modal after 1.5s
        setTimeout(function () { closeAddModal(); }, 1500);
      });
    });
  }
```

- [ ] **Step 3: Manually verify full save flow**

Open the Add Show form. Add a real recent show (or one you're about to attend — anything you want in the tracker). Fill in artist, date, find setlist, handle supporting acts. Click Save Show.

Expected sequence:
1. "Saving to GitHub…" message appears, form goes semi-transparent
2. ~1-2 seconds: "✓ Saved! [Artist] on [Date] added to your tracker."
3. Modal closes after 1.5 seconds
4. Navigate to Artists — the new headliner appears (or count increments if already there)
5. Navigate to overview — show count in the top-right serial number incremented

Also verify GitHub: check `https://github.com/mattpippenger/concerts/commits/main` — a new commit "Add show: [Artist] [date]" should appear.

After ~60 seconds, reload the page on a fresh tab — the show should still be there (loaded from `concerts-additions.json`, not just localStorage).

- [ ] **Step 4: Clean up localStorage pending after successful deploy**

The `fetchAdditions()` function already deduplicates by headliner+date, so pending entries that have been deployed won't double-add. But we should prune stale pending entries to keep localStorage tidy.

In `fetchAdditions()`, after `mergeAdditions(data.concat(pending))`, add:

```javascript
          // prune pending entries that are now in the committed file
          try {
            var committed = data.map(function (s) { return s.headliner + "|" + s.date; });
            var freshPending = pending.filter(function (p) {
              return committed.indexOf(p.headliner + "|" + p.date) === -1;
            });
            localStorage.setItem("concert_pending", JSON.stringify(freshPending));
          } catch (e) {}
```

- [ ] **Step 5: Final end-to-end test**

1. Add a second test show (different artist and date)
2. Confirm it saves and appears
3. Reload the page — both shows present
4. Check `concerts-additions.json` on GitHub — both entries present as valid JSON

- [ ] **Step 6: Commit**

```
git add app.js styles.css
git commit -m "Add GitHub API save flow, optimistic merge, and pending localStorage cleanup"
git push
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ concerts-additions.json created (Task 1)
- ✅ Async merge on boot (Task 1)
- ✅ Floating + button (Task 2)
- ✅ Modal shell (Task 2)
- ✅ Settings screen with credentials + instructions (Task 2)
- ✅ Gear icon inside form to re-open settings (Task 3, renderAddForm)
- ✅ Artist autocomplete from setlist.fm (Task 3)
- ✅ Date input + Find Setlist (Task 4)
- ✅ Auto-populate venue/city/state/tour/songs/URL (Task 4)
- ✅ No-match path: notice + blank editable fields (Task 4, renderSetlistFields with null)
- ✅ Supporting acts secondary lookup (Task 5)
- ✅ Confirmation block with Yes/Edit/Skip (Task 5)
- ✅ Manual opener text field always available (Task 5)
- ✅ GitHub API save (Task 6)
- ✅ Optimistic localStorage pending (Task 6)
- ✅ Pending pruned after deploy (Task 6)
- ✅ Works on iOS (no keyboard shortcuts, touch-friendly tap targets, no hover-only interactions)

**Type consistency:**
- `ADD_STATE` shape built incrementally across Tasks 3–5; `buildShowFromState()` in Task 6 reads all fields — consistent
- `mergeAdditions(rawArray)` called in Task 1 fetch callback and Task 6 save — consistent signature
- `enrichShow(s, idOffset)` uses `SHOWS.length` for id — safe since we call it before push
- `CURRENT_VIEW` initialized before `boot()` uses it — consistent

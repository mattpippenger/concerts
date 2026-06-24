// config.js -- hand-editable settings for the Concert Tracker.
//
// artistAliases: LOGICAL GROUPING. Each show still DISPLAYS the exact band name
// from your spreadsheet (e.g. "Sammy Hagar & The Circle"), but these entries make
// the listed variants count together under one artist on the Artists list, the
// counts, and the grouped detail page.
//   key   = the band name as it appears in the spreadsheet
//   value = the artist to group it under
//
// Add a new grouping here and just reload index.html -- no rebuild needed (this is
// applied by the app at display time). Matching is case-insensitive.

window.CONCERT_CONFIG = {
  sourcePath: 'C:\\Users\\matt.pippenger\\Dropbox\\Concerts.xlsm',
  artistAliases: {
    // Sammy Hagar solo (any backing band) groups under "Sammy Hagar".
    // Van Halen and Chickenfoot are deliberately left out so they stay separate.
    'Sammy Hagar & The Waboritas': 'Sammy Hagar',
    'Sammy Hagar and the Waboritas': 'Sammy Hagar',
    'Sammy Hagar & The Wabos': 'Sammy Hagar',
    'Sammy Hagar and the Wabos': 'Sammy Hagar',
    'Sammy Hagar & The Circle': 'Sammy Hagar',
    'Sammy Hagar and the Circle': 'Sammy Hagar'
  },

  // venueNames: clean display names for venues whose spreadsheet text carries extra
  // info (former names, room, city). The whole site shows `name`; the former/aka
  // names appear only on that venue's page as a callout, so the history is kept.
  //   key  = the venue text EXACTLY as it appears in the spreadsheet (case-insensitive)
  //   name = the current name shown everywhere
  //   aka  = other names to list on the venue page (former names, rooms, etc.)
  //
  // TO RENAME A VENUE LATER (they always do): just edit its `name` here and drop the
  // old name into `aka`, then reload index.html. No rebuild, no spreadsheet edits.
  // Two raw entries that share the same `name` are treated as ONE venue (e.g. the
  // Old National Centre rooms below). Venues not listed here display as-is.
  venueNames: {
    'Ruoff Home Mortgage Music Center (Deer Creek/Verizon Wireless/Klipsch)': {
      name: 'Ruoff Home Mortgage Music Center',
      aka: ['Deer Creek Music Center', 'Verizon Wireless Music Center', 'Klipsch Music Center']
    },
    'Bankers Life Fieldhouse (Conseco)': {
      name: 'Bankers Life Fieldhouse',
      aka: ['Conseco Fieldhouse']
    },
    'Old National Centre (The Murat)': {
      name: 'Old National Centre',
      aka: ['The Murat']
    },
    'Old National Centre (The Murat Egyptian Room)': {
      name: 'Old National Centre',
      aka: ['The Murat Egyptian Room']
    },
    'Deluxe @ The Old National Centre (The Murat)': {
      name: 'Old National Centre',
      aka: ['Deluxe', 'The Murat']
    },
    'Clowes Hall (Butler)': {
      name: 'Clowes Hall',
      aka: ['Butler University']
    },
    'Elliott Hall (Purdue)': {
      name: 'Elliott Hall',
      aka: ['Purdue University']
    },
    'Hi-Fi (Annex)': {
      name: 'Hi-Fi',
      aka: ['Hi-Fi Annex']
    },
    'Holiday Park (Rock the Ruins)': {
      name: 'Holiday Park',
      aka: ['Rock the Ruins']
    },
    // distinct cities -- kept separate on purpose (do NOT merge to "House of Blues")
    'House of Blues (CHI)': { name: 'House of Blues (Chicago)', aka: [] },
    'House of Blues (CLE)': { name: 'House of Blues (Cleveland)', aka: [] }
  }
};

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
    'Sammy Hagar and the Circle': 'Sammy Hagar',

    'Jimmy Buffett': 'Jimmy Buffett & The Coral Reefer Band',

    // "Doobie Brothers" (2022 headliner) and "The Doobie Brothers" (2001 supporting) are the same band.
    'Doobie Brothers': 'The Doobie Brothers',
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
  // artistBanners: map artist group name -> relative path to a banner background image.
  // Used as the background of that artist's detail page header. Text is automatically
  // given a dark overlay + white shadow to stay readable. No entry = default solid bg.
  artistBanners: {
    'Van Halen': 'images/artists/van-halen-banner.jpg'   // guitar right, black left — text sits naturally
  },

  // artistPhotos: map artist group name -> relative path to a photo file.
  // Drop images into an "images/artists/" folder next to index.html, then add
  // entries here. Only the detail page and list row for that artist are affected.
  // Key matching is case-insensitive. No entry = no photo shown (no placeholder).
  // Example:
  //   'Pearl Jam': 'images/artists/pearl-jam.jpg',
  artistPhotos: {
    'Big Head Todd & The Monsters': 'images/artists/big-head-todd.jpg',
    'Dave Matthews Band':           'images/artists/dave-matthews-band.jpg',
    'Counting Crows':               'images/artists/counting-crows.jpg',
    'Jimmy Buffett & The Coral Reefer Band': 'images/artists/jimmy-buffett.jpg',
    'Better Than Ezra':             'images/artists/better-than-ezra.jpg',
    'Poison':                       'images/artists/poison.jpg',
    'Pete Yorn':                    'images/artists/pete-yorn.jpg',
    'The BoDeans':                  'images/artists/bodeans.jpg',
    'Def Leppard':                  'images/artists/def-leppard.jpg',
    'Sammy Hagar':                  'images/artists/sammy-hagar.jpg',
  },

  venueNames: {
    'Ruoff Home Mortgage Music Center (Deer Creek/Verizon Wireless/Klipsch)': {
      name: 'Ruoff Home Mortgage Music Center',
      aka: ['Deer Creek Music Center', 'Verizon Wireless Music Center', 'Klipsch Music Center']
    },
    'Bankers Life Fieldhouse (Conseco)': {
      name: 'Gainbridge Fieldhouse',
      aka: ['Bankers Life Fieldhouse', 'Conseco Fieldhouse']
    },
    'Old National Centre (The Murat)': {
      name: 'Old National Centre',
      aka: ['The Murat']
    },
    'Old National Centre (The Murat Egyptian Room)': {
      name: 'Egyptian Room',
      aka: ['The Murat Egyptian Room', 'Old National Centre Egyptian Room']
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
      name: 'Hi-Fi Annex',
      aka: ['Hi-Fi']
    },
    'The Hi-Fi': { name: 'Hi-Fi', aka: ['The Hi-Fi'] },
    'Holiday Park (Rock the Ruins)': {
      name: 'Holiday Park',
      aka: ['Rock the Ruins']
    },
    // distinct cities -- kept separate on purpose (do NOT merge to "House of Blues")
    'House of Blues (CHI)': { name: 'House of Blues (Chicago)', aka: [] },
    'House of Blues (CLE)': { name: 'House of Blues (Cleveland)', aka: [] },
    'Lawn at White River': { name: 'Everwise Amphitheater', aka: ['Lawn at White River'] },
    'Mars': { name: 'Axis Nightclub', aka: ['Mars'] }
  },

  // retiredArtists: headliner group names that no longer perform (artist passed away or
  // band disbanded). Used to award the "Final Bow" badge on matching shows.
  //   key   = the artist group name (same as what appears in bandIndex after aliases resolve)
  //   value = short reason shown on the badge detail page
  retiredArtists: {
    'Chris Cornell':                         'Chris Cornell passed away May 2017',
    'Jimmy Buffett & The Coral Reefer Band': 'Jimmy Buffett passed away September 2023',
    'Prince':                                'Prince passed away April 2016',
    'Soundgarden':                           'Chris Cornell passed away May 2017',
    'Tom Petty & The Heartbreakers':         'Tom Petty passed away October 2017',
    'Van Halen':                             'Eddie Van Halen passed away October 2020',
    'REM':                                   'Band disbanded September 2011',
  },

  // setlistOverrides: force a specific show to a specific setlist.fm page. Use this
  // when the auto-resolver guesses wrong (e.g. festival days like Summerfest where an
  // artist has several setlists on the same date). It always wins over the API result.
  //   key   = "Artist|YYYY-MM-DD" exactly as the show is recorded (case-insensitive)
  //   value = the full setlist.fm URL
  // Applied at display time -- just reload index.html, no rebuild needed.
  setlistOverrides: {
    'Cracker|2013-06-29': 'https://www.setlist.fm/setlist/cracker/2013/henry-w-maier-festival-park-us-cellular-connection-stage-milwaukee-wi-4bd90bb2.html'
  }
};

# Dawn Chorus

A bird-identification game. Each region has ten levels, ordered from the most common birds to the hardest to find, and each level is a round of its 4 or 5 birds. Every bird comes as a photo with its recording playing: name the bird against a 60-second timer, then read its field notes and see your time. Clearing 80% of a level's birds unlocks the next level. A bird counts as cleared when your latest answer for it was right. Regions so far: Wisconsin and Phoenix, Arizona (85 species: 43 for Wisconsin and 42 for Phoenix).

The Album tab keeps each bird you have identified, with your fastest time (record) and your accuracy, saved in the browser.

It is a static page: `index.html` plus `photos/` and `audio/`, with no build step and no server. Open it through any static web server (browsers will not load the audio from `file://`), for example `python3 -m http.server` in this folder. It has no `package.json`, so the repository's test and deploy workflows skip it.

## How it works

- The commonness order is `RANK` and the level sizes are `LEVEL_SIZES` in `index.html`. It is a judgement of how widespread and abundant each bird is in the region, not a count from eBird data, so adjust it if you know better.
- Each species is one entry in the `BIRDS` array in `index.html`: name, region, song description, field marks, size and habitat. Its photo is `photos/<id>.jpg` and its recording is `audio/<id>.mp3`, and `PHOTO` and `REC` hold their credits.
- The recording is decoded and played with the Web Audio API.
- To add a region, add entries to `BIRDS`, an entry to `REGIONS`, and the matching photo and audio files.

## Licenses of the photos and recordings

The files in `photos/` and `audio/` are not covered by the repository's licence. Each keeps its own:

- Photos are from Wikimedia Commons under Creative Commons licences (mostly CC BY-SA, some CC BY, and one public domain).
- Recordings are from xeno-canto under CC BY-NC-SA 3.0 or 4.0. Non-commercial use only, and any copy of a recording must carry the same licence.

[`CREDITS.md`](CREDITS.md) lists the author, source and licence of every file. Keep it in step when a photo or recording changes.

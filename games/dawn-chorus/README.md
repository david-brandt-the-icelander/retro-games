# Dawn Chorus

A bird-identification game. Each round shows ten birds from the chosen region, each as a photo with its recording playing. Name each bird against a 60-second timer, then read its field notes and see your time. The Score tab keeps the birds you have identified and your fastest time for each, saved in the browser. Regions so far: Wisconsin and Phoenix, Arizona (85 species: 43 for Wisconsin and 42 for Phoenix).

It is a static page: `index.html` plus `photos/` and `audio/`, with no build step and no server. Open it through any static web server (browsers will not load the audio from `file://`), for example `python3 -m http.server` in this folder. It has no `package.json`, so the repository's test and deploy workflows skip it.

## How it works

- Each species is one entry in the `BIRDS` array in `index.html`: name, region, song description, field marks, size and habitat. Its photo is `photos/<id>.jpg` and its recording is `audio/<id>.mp3`, and `PHOTO` and `REC` hold their credits.
- The recording is decoded and played with the Web Audio API.
- To add a region, add entries to `BIRDS`, an entry to `REGIONS`, and the matching photo and audio files.

## Licenses of the photos and recordings

The files in `photos/` and `audio/` are not covered by the repository's licence. Each keeps its own:

- Photos are from Wikimedia Commons under Creative Commons licences (mostly CC BY-SA, some CC BY, and one public domain).
- Recordings are from xeno-canto under CC BY-NC-SA 3.0 or 4.0. Non-commercial use only, and any copy of a recording must carry the same licence.

[`CREDITS.md`](CREDITS.md) lists the author, source and licence of every file. Keep it in step when a photo or recording changes.

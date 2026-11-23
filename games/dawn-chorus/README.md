# Dawn Chorus

A bird-identification game. Each region has ten levels, ordered from the most common birds to the hardest to find, and your level for the region is a number on the Play tab. A game is 10 random birds: your level's birds, plus any bird from your level or below you have not identified yet, plus 4 random birds from lower levels, topped up from the next level if that is fewer than 10. Every bird comes as a photo with its recording playing: name the bird against a 60-second timer, then read its field notes and see your time. When 80% of your level's birds are cleared, you move up a level. A bird counts as cleared when your latest answer for it was right. The region selector lists all 50 states alphabetically. Only Wisconsin (43 species) and Arizona (42 species, from the Phoenix area) have birds so far; the other states show a message until birds are added.

The Album tab keeps each bird you have identified, with your fastest time (record) and your accuracy, saved in the browser.

It is a static page: `index.html` plus `photos/` and `audio/`, with no build step for the page itself. `photos/thumb/` holds small copies of the photos for the scrolling strip on the Play tab. To try it, run `python3 -m http.server` in this folder and open it in a browser (browsers will not load the audio from `file://`).

## Deploy

`worker/index.ts` is a Cloudflare Worker at `icelander.net/games/retro/dawn-chorus`: it serves `dist/` to anyone signed in to icelander.net (role `games:play`, through `vendor/icelander-auth`) and sends everyone else to the site's sign-in. No database, no secrets. `npm test` checks the Worker; `npm run build` copies the page, photos and audio into `dist/`; `npm run deploy` runs both and `wrangler deploy`. Nothing deploys from GitHub any more: the owner runs `npm run deploy` from their own machine.

## How it works

- The commonness order is `RANK` and the level sizes are `LEVEL_SIZES` in `index.html`. It is a judgement of how widespread and abundant each bird is in the region, not a count from eBird data, so adjust it if you know better.
- Each species is one entry in the `BIRDS` array in `index.html`: name, region, song description, field marks, size and habitat. Its photo is `photos/<id>.jpg` and its recording is `audio/<id>.mp3`, and `PHOTO` and `REC` hold their credits.
- The recording is decoded and played with the Web Audio API.
- To add a state, add its birds to `BIRDS` with that state's two-letter lowercase code as `region`, its commonness order to `RANK` and its level sizes to `LEVEL_SIZES`, and the matching photo, thumbnail and audio files.

## Licenses of the photos and recordings

The files in `photos/` and `audio/` are not covered by the repository's licence. Each keeps its own:

- Photos are from Wikimedia Commons under Creative Commons licences (mostly CC BY-SA, some CC BY, and one public domain).
- Recordings are from xeno-canto under CC BY-NC-SA 3.0 or 4.0. Non-commercial use only, and any copy of a recording must carry the same licence.

[`CREDITS.md`](CREDITS.md) lists the author, source and licence of every file. Keep it in step when a photo or recording changes.

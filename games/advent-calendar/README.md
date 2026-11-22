# Advent Calendar

A storybook Advent calendar for phones and desktop browsers. No build step to play it, no server.

A painted log house stands in the snow under the aurora, with 24 arched wooden doors in its wall. Tapping a door curls it open like paper, and the window grows into a framed card where a friend does one short animation: it waves, plays peek-a-boo, throws a snowball at the screen, sings. The animation plays once and ends on a held pose. The friend keeps watching the child's finger, and beams when the finger rests on its face. Tapping the card closes the window and the door swings shut. Tapping the door again replays the animation.

It lives at <https://icelander.net/games/fresh/advent-calendar/>, **for invited players only**: every file is served only to someone signed in to icelander.net who holds the role `games:advent-calendar`. The role is declared in the icelander.net repository (`accounts/src/config.js`) and granted, or sent as an invitation, at <https://icelander.net/private/admin>. The games page lists the calendar only to holders of the role.

## Running it

Open `index.html` in a browser. It needs `calendar.js` and the `assets/` folder beside it. Nothing else is fetched except the Google Fonts.

## Dates

Window N opens on N December, and opened windows (marked with a gold star) are remembered in `localStorage`. In December, today's door glows; outside December every door stays shut.

**Developers** (holders of `games:advent-calendar-dev`, granted at <https://icelander.net/private/admin>) also get, under the house, the preview switch (every window opens, before its date) and "Close and forget all the windows". The page asks the Worker (`me.json`) which it is; everyone else sees only a line saying when windows open. So that a window can't be opened early by editing the page, the Worker sends a window's backdrop (`assets/bg-NN.webp`) to a non-developer only from day NN of December, by the calendar date furthest ahead anywhere (UTC+14). With no Worker in front (the page opened from a file, or a plain static server such as `art/snap.mjs`'s), there is no `me.json` and the page is in developer mode.

## Files

- `index.html`: the page and its stylesheet.
- `calendar.js`: the game. It places the doors, runs the peel, poses the characters and plays the 24 scenes. It is a file of its own so the page's Content-Security-Policy can forbid inline script.
- `assets/`: the art, made by `art/build.mjs`. Do not edit these files by hand.
  - `house.webp` is the house.
  - `doors.webp` holds the door fronts, in six decorations, and the door back.
  - `common.webp` holds the card frame, the snow ledge and the props.
  - `sp-<species>.webp` holds one friend's parts.
  - `bg-01.webp` to `bg-24.webp` are what each window looks onto.
  - `art.js` is the manifest: sprite rectangles and pivots, the window grid, and light positions.
- `art/`: the art sources and tools. They need Node 22 or later and Google Chrome, and install nothing. They are not part of the site.
- `worker/index.ts`: the Worker. It serves every file only to holders of `games:advent-calendar`, answers `me.json` (developer or not), and holds back future backdrops from non-developers; `worker/config.ts` holds the address, the two roles and the date rule.
- `web/_headers`: the Content-Security-Policy and the other headers for the static files.
- `build.mjs`: copies the page, its script and `assets/` into `dist/`, and builds the tests.
- `test/worker.test.ts`: who may fetch what.

The page loads the house and doors (about 200 KB) with itself. A window's pictures (35–50 KB, plus the 105 KB of shared props the first time) load when its door is pressed, and the shared props also load in the background once the house is up. All the art together is about 1.1 MB.

## How the art is made

The art is original. It is drawn in code as SVG, then rendered to WebP at about 2× for phone screens, so it can be changed and rebuilt. The painted look comes from SVG filters in `art/paint.mjs`:

- a soft shadow on the side away from the light, and a warm rim on the lit side;
- a slight wobble on every edge;
- mottled colour and paper grain;
- fur strokes, and displacement for fuzzy edges.

- `art/characters.mjs` paints each friend as separate parts, each drawn around its pivot: body, head, ears, eyes, blink, mouths, tongue, beak, hat, scarf, arms and tail. The game's `creature()` rig turns and scales those parts from a pose (arm angles, head turn, look, blink, mouth open, ears, tail).
- `art/house.mjs` paints the house and the shutter doors. `WIN` there is the window grid the game uses.
- `art/common.mjs` paints the card frame, the ledge and the props.
- `art/backdrops.mjs` paints the 24 backdrops.
- `art/sheets.mjs` lists every output file.

To rebuild, run these from this folder:

```bash
node art/build.mjs              # everything
node art/build.mjs 'sp-*' house # some sheets only
```

`art/render.html?sheet=NAME` shows one sheet in a browser.

## Checking it

`node art/snap.mjs [DIR]` drives the page in headless Chrome. It saves screenshots and fails on any page error:

- the house at phone (390×844) and desktop sizes;
- a door peeling open, the card playing, closing and opening again;
- contact sheets of all 24 windows at 0.6, 2, 3.5 and 6 seconds;
- one window under reduced motion.

The page also has two test hooks, for developers only. `?sheet=0.6,2` draws every card at those moments. `?open=N&t=SECONDS` opens window N, held at that moment.

With reduced motion, doors open without the curl, and each window shows its friend's final pose.

## Deploy

`npm install`, then `npm test` checks the Worker and `npm run build` makes `dist/`. A merge to `main` that changes this folder deploys it (`.github/workflows/deploy.yml`), as `npm run deploy` does by hand. The Worker's route is `icelander.net/games/fresh/advent-calendar*`, and it needs icelander.net's login service (the `accounts` Worker) deployed with the role `games:advent-calendar` declared.

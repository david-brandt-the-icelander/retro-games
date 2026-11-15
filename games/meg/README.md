# MEG: The Current Remembers

An original retro shark game for the browser, on desktop and phone. You are the last megalodon. A warm current has hidden your kind for millions of years, and a shadowy agency, the Directorate, is closing in. Stay fed, stay hidden and protect the current across eight incident files.

MEG is not a remake: its story, characters and look are its own.

## Play

Open `index.html` in a browser. It is one self-contained page: the game, its pixel art and its synthesized sound are all inline. The only things it loads from outside are three Google Fonts (Press Start 2P, Special Elite and VT323), and it falls back to system fonts without them.

## Controls

| Action | Keyboard | Phone | Gamepad |
|---|---|---|---|
| Turn counterclockwise / clockwise | ← → or A D | ↺ ↻ (bottom left) | Left stick or d-pad |
| Speed up (hold), slow down (release) | Space (also ↑ or W) | SWIM (bottom right) | A or right trigger |
| Pause | P or Esc | PAUSE | |
| Sound on/off | M | SOUND | |

Everything else is automatic:

- **Biting:** the jaws snap shut on anything edible the mouth touches.
- **Breaching:** hit the surface heading upward at full speed (the speed bar turns yellow) and the shark leaps clear of the water. Landing on a deck damages the ship. At full speed the shark also rams hulls from below.
- **Hiding:** inside the glowing warm current, nothing can see the shark.

## How it plays

Hunger drains all the time, and faster at speed; fish, squid and whales refill it. Exposure rises when lights, sonar, cameras or spotlights catch the shark, and falls when it hides deep or in the current. When exposure fills, a hunter fleet drops depth charges for a while. Each file opens with a typed, redacted Directorate document and closes with a cover-story memo.

| File | Goal |
|---|---|
| 1 The Trawler at Night | Eat 12 fish from around the net |
| 2 Buoy Line | Destroy 5 sonar buoys |
| 3 The Photographer | Take the diver's camera before he reaches his boat |
| 4 Whale Migration | Take 8 bites of whale |
| 5 The Research Sub | Cut the sub's tether, or lure it over the hot vents |
| 6 Cover-Up | Sink 2 dumping ships before the current goes cold |
| 7 Storm Breach | Bring down the hunter ship |
| 8 The Directorate's Base | Destroy 3 turrets and free the young one |

Progress (the highest file reached) and the sound setting are kept in the browser's `localStorage`.

## Files

| Path | What it is |
|---|---|
| `index.html` | The whole game: styles, HUD and touch controls, then one script with the audio, input, entities, the eight levels, the simulation loop, drawing and the menu screens |
| `.dev/` | This folder's diagrams and knowledge files |

## Status

MEG is not yet part of icelander.net. Unlike the other games it has no `package.json`, Worker, sign-in or high-score table, so the deploy workflow (`.github/scripts/changed-games.sh` lists only games with a `package.json`) leaves it alone. Whether and how to publish it is an open decision in `.dev/decisions.json`; the work it would take is in `.dev/backlog.json`.

# MEG: The Current Remembers

An original cartoon shark game for the browser, on desktop and phone. You are the last megalodon. A warm current has hidden your kind for millions of years, and a shadowy agency, the Directorate, is closing in. Stay fed, stay hidden and protect the current across eight incident files.

MEG is not a remake: its story, characters and look are its own.

## Play

Open `index.html` in a browser. It is one self-contained page: the game, its cartoon art (drawn as vector shapes on a canvas at the screen's full pixel density) and its synthesized sound are all inline. The only things it loads from outside are three Google Fonts (Lilita One, Nunito and Special Elite), and it falls back to system fonts without them.

## Controls

| Action | Keyboard | Phone | Gamepad |
|---|---|---|---|
| Turn counterclockwise / clockwise | ← → or A D | ↺ ↻ (bottom left) | Left stick or d-pad |
| Speed up (hold), slow down (release) | Space (also ↑ or W) | SWIM (bottom right) | A or right trigger |
| Pause | P or Esc | PAUSE | |
| Sound on/off | M | SOUND | |

Everything else is automatic:

- **Biting:** the jaws snap shut on anything edible the mouth touches, including the swimmers bobbing at the surface, who panic and draw attention when they spot the shark.
- **Breaching:** hit the surface heading upward at full speed (the speed bar turns yellow) and the shark leaps clear of the water. Landing on a deck damages the ship. At full speed the shark also rams hulls from below.
- **Hiding:** inside the glowing warm current, nothing can see the shark.

## How it plays

Strength drains all the time, and faster at speed; eating restores it. Every live catch leaves a ragged blood cloud that drifts apart and thins out. A whale dies at the first bite, which takes a chunk out of it; the carcass rolls belly-up and floats up, can be bitten on the way, and raises exposure sharply when it reaches the surface. Exposure rises when lights, sonar, cameras or spotlights catch the shark, and falls when it hides deep or in the current. When exposure fills, a hunter fleet drops depth charges for a while. A charge tumbles down and bursts in a bubble blast when it touches anything (the shark, fish, a whale, the sub, the seabed) or at a random depth at least a third of the way from the surface to the seabed. Each file opens with a redacted Directorate document that a teleprinter types out, with key clacks, heavier strikes on the redactions, a bell and carriage return at each line and a double ding at the end; tap it to skip. Each file closes with a cover-story memo.

## Prey and score

Every catch scores points, more for bigger or more darkly funny prey. A cleared file adds a bonus of 500 × the file number plus 10 per point of strength left. The score carries through a run of files and ends when the shark fails, after the last file, or with End run.

| Prey | Points | Where |
|---|---|---|
| Reef fish | 10 | Everywhere, in schools |
| Squid | 20 | Schools |
| Cod, haddock | 25 | Schools; the trawler's net is full of them |
| Salmon | 40 | Schools |
| Whale | 100 a bite, up to 6 | File 4 |
| Seal | 120 | Near the surface |
| Seagull | 150 | Above the waves; only by breaching |
| Manta ray | 150 | Mid-water |
| Dolphin | 200 | Pods of two or three; they flee and leap |
| Puffin | 200 | Above the waves; only by breaching |
| Swimmer | 250 | At the surface; they panic and draw attention |
| Scuba diver | 300 | Now and then, deep |
| Greenlandic kayaker | 400 | At the surface, in a qajaq |
| Polar bear | 500 | Swimming at the surface; swipes back |

Visitors wander in over time and leave again; swimmers and kayaks keep clear of boats. Sabotage scores too: buoys, ships, the sub, drums, turrets and drones.

The high-score table keeps the ten best runs on this device, with a name entered when a run ends with a qualifying score.

## Files to clear

| File | Goal |
|---|---|
| 1 The Trawler at Night | Eat 12 fish from around the net |
| 2 Buoy Line | Destroy 5 sonar buoys |
| 3 The Photographer | A dive boat races about above and drops a diver in behind you, closer and more accurately the more exposed you are. He photographs scenery, and you if you come within half a screen of him outside the current. With a photo he races back at 70% of your top speed; if he climbs aboard with it you lose. Catch him first |
| 4 Whale Migration | Take 8 bites of whale |
| 5 The Research Sub | Cut the sub's tether, or lure it over the hot vents |
| 6 Cover-Up | Sink 2 dumping ships before the current goes cold |
| 7 Storm Breach | Bring down the hunter ship |
| 8 The Directorate's Base | Destroy 3 turrets and free the young one |

Progress (the highest file reached), the sound setting, the high-score table and the last name entered are kept in the browser's `localStorage`.

## Files

| Path | What it is |
|---|---|
| `index.html` | The whole game: styles, HUD and touch controls, then one script with the audio, input, entities, the eight levels, the simulation loop, drawing and the menu screens |
| `.dev/` | This folder's diagrams and knowledge files |

## Status

MEG is not yet part of icelander.net. Unlike the other games it has no `package.json`, Worker, sign-in or high-score table, so the deploy workflow (`.github/scripts/changed-games.sh` lists only games with a `package.json`) leaves it alone. Whether and how to publish it is an open decision in `.dev/decisions.json`; the work it would take is in `.dev/backlog.json`.

# Handyman Jim

A small Godot 4 comedy game. Jim is a blond, balding, beer-bellied fix-it-all guy in Marshfield,
Wisconsin, and he's always smiling. The phone rings,
somebody has done something unbelievably dumb, and Jim has to buy the parts, drive over and fix it
before the customer gives up on him.

**Engine:** Godot 4.3 or newer, using the Compatibility renderer, so it runs on almost anything.
Open `project.godot` and press F5.

## Controls

| Key | Does |
|---|---|
| Arrows / WASD | Drive the van (Up = gas, Down = brake/reverse); walk left/right indoors |
| E / Space | Go in, talk, buy, fix, continue. While driving with nowhere to go in, honk |
| Enter / M / Tab | Map and job board on one screen: streets by name, every shop, the job's parts checklist, where to buy each part and today's sales. The whole game is frozen while it's open. Enter also continues a dialog |
| H | Horn |
| Esc | Leave a menu or the map |

## How a day goes

- **7:00 AM** Jim starts in his shop and the phone rings with the first job. Each call comes with a
  work order: where, what it pays, the deadline and the materials. Jim takes one job at a time:
  the phone rings again a few minutes after he finishes one.
- **Shopping.** Six stores stock different things at different prices, and four random sales run
  every day. The job board shows them, and so does the bartender at the Rusty Muskie for $5.
  Leftovers sell back for half price.
- **Sound.** The phone rings (answer it with E, Space or Enter), and people "bla-bla-bla" as their
  words type out, each speaker in their own pitch; Jim's voice is the low one. Every sound is
  generated in code by `scripts/sfx.gd`, so there are no audio files.
- **Driving.** Rolling into a driveway or parking lot stops the van. The camera is zoomed out so you can see the road ahead, and the corner minimap
  flashes the shops that sell what the job still needs. The van still takes a while to stop.
  Here is what can go wrong:
  - Trash cans $40, mailboxes $75, hydrants $150, cones $15, buildings $60, fender benders $300.
  - Red lights: a ticket if a cop or bystander sees you. The third ticket in a day means jail.
  - Hitting a pedestrian or a Packers fan, or ramming the squad car, means jail on the spot. You pay
    bail and lose the rest of the day.
  - Random road events: a loose cow, geese, a guy on a riding mower, a spilled cheese-curd truck
    (slippery), cones, a fan parade, and a deer staring you down.
  - Gas runs out. Fill up at the Gas-N-Grub, or Earl tows you there for $120.
- **Houses.** Each customer house has three rooms joined by doors on the left and right. The mess is in
  one of them, so find it and press E. A fix takes 30 game minutes. A late fix pays half.
- **Getting paid.** Customers pay in cash or by cheque. You cash cheques at First Dairyland Bank, which
  is open 9 AM to 5 PM. Some cheques bounce, and each bounce costs a $25 fee.
- **7:00 PM** is quitting time. Unfinished jobs go to cousin Lyle. Then the Zzzz screen.
- **Friday night** brings a weekend scene that depends on your cash: beans in the dark, TV with a
  beer and the dog, fish fry, the bar, fishing, or a hunting trip Up North. Monday morning, $250 rent is due.

One game minute is one real second, so a day lasts 12 real minutes.

## Project layout

```
main.tscn            the only scene; everything else is built in code
scripts/main.gd      game flow: title, calls, day end, jail, weekend
scripts/game.gd      autoload "Game": clock, money, cheques, inventory, jobs, sales
scripts/data.gd      ALL content: items, stores, the 15 jobs, road events, fines, weekends
scripts/town.gd      street grid and building placement
scripts/drive.gd     top-down driving, traffic, lights, pedestrians, road events
scripts/room_view.gd building fronts and rooms, stores/bank/bar menus, fixing
scripts/cutscene.gd  title, Zzzz, jail, weekend scenes
scripts/hud.gd       status bar, job list, minimap, arrows, job board
scripts/dialog.gd    message boxes (typed out, with speech babble) and menus
scripts/sfx.gd       autoload "Sfx": phone ring, horn and per-speaker speech, synthesised at start-up
scripts/art.gd, pal.gd  cartoon drawing helpers and the 16-colour palette
tests/               smoke.tscn (screenshots of every screen), flow.tscn (headless logic test)
```

**To add a job,** append an entry to `Data.JOBS`. Its `prob` must be one of: toilet,
ceiling_hole, critter, window, wires, garage, water, wall_hole, door, deck, fence, roof, glued.
Its `room` must be one of: Living Room, Kitchen, Bathroom, Bedroom, Basement, Garage, Attic,
Back Deck, Back Yard.

**Tests:**

```
godot --headless --path . res://tests/flow.tscn
xvfb-run godot --path . --rendering-driver opengl3 res://tests/smoke.tscn
```

The smoke test saves its screenshots to `user://shots`. Set the `SHOTS` environment variable to put
them somewhere else.

## Art

Every picture in the game is drawn by code in a flat cartoon style (rounded shapes, ink outlines,
a 16-colour palette), so the game runs with no asset files at all. To swap in AI-generated backgrounds, see [ART_STYLE.md](ART_STYLE.md).

## Playing in a web browser

`export_presets.cfg` has a **Web** preset with threads turned off. The export then runs on any plain
static host (itch.io, GitHub Pages, Netlify, or any web server) with no special server headers.

1. In Godot, install the export templates: **Editor > Manage Export Templates > Download**.
2. Go to **Project > Export > Web > Export Project**. This writes `build/web/index.html` and its files.
   From the command line, run `godot --headless --export-release "Web" build/web/index.html`.
3. Upload the `build/web` folder. For itch.io, zip the folder's contents and mark the upload
   "This file will be played in the browser".

Opening `index.html` straight from disk (`file://`) won't work, because browsers block loading the
engine that way. Serve it instead: `python3 -m http.server` in `build/web`, then open http://localhost:8000.

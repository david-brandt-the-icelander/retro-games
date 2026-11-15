# Backseat Driver

A short comedy game for Godot 4 (written against 4.3, GL Compatibility renderer).

You are the front-seat passenger. The driver is confident and distracted. Signs and
hazards roll toward the windshield — ducks, gators, school buses, a very slow man
with a walker, a hairpin curve, a logging truck. You can only talk. Pick what to say
before the timer runs out: say the right thing and the driver (grudgingly) saves the
day; say nothing, or the wrong thing, and whatever the sign warned about happens.
Three strikes and the car is totaled.

## Run

1. Open Godot 4.3 or newer, **Import** this folder (`games/backseat-driver/project.godot`).
2. Press **F5**.

## Controls

| Input | Action |
|---|---|
| `1` / `2` / `3` or click a button | Say that thing to the driver |
| `Space` / `Enter` / click | Start, and restart after a wreck |

## Design notes

- Everything is drawn in code (`_draw()`), so there are no art or audio assets.
- `events.gd` holds all 16 road events as plain data. The **first** option of each is
  the correct one; `main.gd` shuffles them. Add an event by appending a dictionary there
  and, for a new hazard picture, a function in `hazards_a.gd` / `hazards_b.gd`.
- The reaction window shrinks as you handle more signs (6.8 s down to 3.6 s).
- Best score is saved to `user://backseat_driver.cfg`.

## Play in a browser

`web/backseat-driver.html` is an HTML5 canvas port of the same game (data shared via `events.gd`). Rebuild it with `python3 web/build.py` after editing `events.gd` or `web/src/`.

### How it plays (web build)

The view is out of the windshield. A sign or situation appears and you get three things to scream at the driver; tap a message or press 1, 2 or 3. The speedometer is on the dash and the driver obeys: scream "slow down" and the needle drops, "floor it" and it climbs. Too fast, too slow or the wrong scream triggers that sign's disaster. Engine, road noise, passing traffic, horns and event cues are synthesised with WebAudio (M mutes). The Godot project is the earlier version and does not yet have the speedometer or sound.

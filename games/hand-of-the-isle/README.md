# Hand of the Isle

A modern god game for **Godot 4.4+**: you don't command your followers directly — you
reshape the island they live on and call down divine powers, while a rival deity does the
same. Everything (terrain, buildings, people, interface) is generated in code; there are no
external assets.

## Running

1. Install Godot 4.4 or newer (standard build, no .NET needed).
2. In the Project Manager choose **Import**, select this folder's `project.godot`, then press **F5**.

The title screen plays a rival-against-rival match in the background. Pick a rival:
*Gentle*, *Even match* or *Wrathful*.

## How it plays

- **Flat land is everything.** A walker that finds a flat, dry, unclaimed tile builds a home.
  The more flat land at the same height around it, the larger the home grows:
  **Hut** (1×1, 6 people) → **House** (3×3, 18) → **Castle** (5×5, 44).
- **Homes breed followers.** A full home sends out a walker carrying half its people.
- **Followers produce faith**, bigger homes more per person. Faith pays for everything.
- **Influence.** You can only sculpt near your own people — the bright part of the island.
  The rest is dimmed.
- Homes whose ground is no longer flat collapse (half the people survive); homes under the
  sea drown.
- You win when the rival has no people left.

### Follower behaviour (Z / X / C)

| | |
|---|---|
| **Settle** | Seek flat land, build, and join unfilled homes |
| **Gather** | March to your Beacon and merge into one strong band |
| **Crusade** | Hunt the rival's walkers and besiege their homes |

### Powers (1–8)

| Power | Faith | Effect |
|---|---|---|
| Sculpt | 1 | Left-click raises a corner, right-click lowers it; neighbours follow so slopes stay gentle |
| Beacon | 10 | Rally point for Gather |
| Earthquake | 120 | Scrambles the ground in a radius, toppling homes |
| Swamp | 170 | Bogs on flat ground that swallow walkers; reshaping clears them |
| Champion | 260 | Your strongest walker becomes a haloed hero who crusades on its own |
| Volcano | 460 | Raises a mountain strewn with unbuildable rock |
| Flood | 720 | Raises the sea one step everywhere — both sides suffer |
| Armageddon | 1200 | Every home empties and both peoples march to a final battle |

Hold **Shift** while casting to keep the power selected.

### Controls

| Input | Action |
|---|---|
| Left / right mouse (hold to repeat) | Raise / lower land, or cast the selected power |
| W A S D / arrows | Pan |
| Q / E, middle-drag | Rotate |
| Mouse wheel | Zoom |
| Space | Pause |
| F | Fast-forward ×3 |
| Home | Centre on your people |
| Esc | Back to Sculpt / close help |
| H | Help |

## Code layout

| File | Role |
|---|---|
| `scripts/main.gd` | Scene dressing (sky, sun, sea), input, cursor, game states |
| `scripts/world.gd` | Simulation: settlements, walkers, combat, faith, powers |
| `scripts/terrain.gd` | Heightmap, sculpting, low-poly mesh, water, trees |
| `scripts/terrain.gdshader` | Vertex-colour terrain with the influence overlay and tile grid |
| `scripts/settlement.gd`, `scripts/walker.gd` | Units and their procedural models |
| `scripts/rival_ai.gd` | The rival deity — obeys the same rules and costs as you |
| `scripts/camera_rig.gd` | Orbiting tabletop camera |
| `scripts/hud.gd` | Interface built in code |

Tunable numbers live at the top of `world.gd` (`POWERS`, `WALKER_CAP`, `MANA_MAX`), in
`Settlement.CAP`, and in `RivalAI` (think rate, sculpt budget, crusade grace period per
difficulty).

### Test switches

Arguments after `--` on the command line:
`--autoplay` (AI plays both sides; logs balance every 30 s; combine with `--headless`),
`--play` (skip title), `--level=0..2`, `--seed=N`, `--speed=N`, `--zoom=N`,
`--shot=out.png --shot-time=S` (save a screenshot and quit), `--click-test`,
`--quit-after=S`.

```sh
godot --headless --path . -- --autoplay --speed=20 --quit-after=60
```

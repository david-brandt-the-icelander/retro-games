# LodeStar: design (Rust and Godot 4, desktop)

Working design, 8 November 2026. **LodeStar** is the working title; `lodestar` is its slug. The GDD phase confirms the title.

## Summary

The game is a new work in the public `retro-games` repo: it plays like a 1984 BBC Micro space trading game (same mechanics, same 12 Hz flight model, same AI), but with its own galaxy, market, names and text, a third-person camera that always shows your ship, and modern 3D art. Its simulation is a Rust crate, presented through Godot 4.7 with godot-rust, and it ships as a desktop game for Windows, macOS and Linux. There is no web build.

The main decisions:

| Decision | Choice | Why |
| --- | --- | --- |
| Repo and process | `retro-games/games/lodestar/`, made with the repo's `create-retro-game` skill: gated phases, clean-room roles | It is a remake, not a recreation; the repo is public during development |
| Where the rules come from | A clean-room behaviour spec (`docs/RULES.md`) written from the private TypeScript recreation; the Rust and Godot code is written from the spec only | Nothing of the original or the faithful clone is copied |
| Original data | Galaxy generation, market table, all text and all names are new **before the first push** | Your rule: the public repo never holds the original's data |
| Simulation vs. picture | A pure, deterministic Rust sim at 12 Hz with no engine dependency; a Godot presentation that interpolates and decorates | Mechanics stay retro while art is free to be modern |
| Hybrid | Single-player embeds the sim crate in the game; a later multiplayer server runs the same crate as the authority | One set of rules, so the server never drifts from the client |
| Hit detection, targeting, collisions | Spec'd from the original's maths; meshes are cosmetic | Changing them would change the game |
| Camera | Third person, EVE-style orbit around your ship, with a limited zoom range | Your decision; the one deliberate change to how the game plays |
| Ships | The ACNX-7 Cheetah GLB takes the heavy trader and pirate role, and stands in for every other ship until more models exist | One model for now |
| Engine binding | Godot 4.7 with godot-rust (`gdext`, GDExtension); scenes and presentation scripts in GDScript | Rust for the rules, Godot for the picture; godot-rust is mature on desktop |
| Platform | Desktop only: Windows, macOS, Linux, keyboard and mouse. No web build | godot-rust in Godot's web export is still experimental; desktop removes the sign-in gate, file-size limits and browser-owned keys |
| Renderer | Forward+, with Compatibility as the fallback for old GPUs | Full glow, shadows and MSAA on desktop |
| Source layout | Layered, after [A hundred and fifty diagrams before breakfast](https://icelander.net/v1/processes/a-hundred-and-fifty-diagrams-before-breakfast): use cases, features and capabilities in Rust, presentation in Godot, infrastructure and hosting around them, with `.dev/` diagrams beside the code | Agents find their way by the folders, and the diagrams stay true |

The title must not echo the original's. Choosing it is part of the GDD phase; `lodestar` is a working label.

## What "retro gameplay" means

The test for every feature: a player of the 1984 game should recognise every system and make the same kinds of decisions. The mechanics are kept; the data they run on is new; the camera is the one deliberate change.

**Kept (specified in RULES, then implemented fresh):**

- The shape of the universe: 8 galaxies of 256 procedurally generated systems, each with economy, government, tech level, population, productivity and size, nearest-system search, a galactic jump.
- How trade works: goods whose price and availability depend on economy and a per-visit fluctuation, a cargo hold, equipment gated by tech level.
- Flight: roll and pitch rates with damping and auto-centre, the speed range, the station safe zone, docking checks, in-system jump, sun heat and fuel scooping, altitude, hyperspace and the alien ambush mid-jump.
- Combat: the AI's behaviour, lasers and laser heat, missiles and E.C.M., area blast, fore and aft shields and energy banks, damage, bounties, ranks, legal status and police, spawning rules.
- At most 13 objects in the bubble, which is also what makes detailed 3D models affordable.

**New (must exist before the first push):**

- Galaxy generation: our own generator and seeds, so every system, name and position differs from the original's.
- Market: our own goods, base prices, gradients and fluctuation ranges.
- All text and names: ships, station, aliens, goods, ranks, legal statuses, messages, screen labels.

**Changed on purpose:** you always see your own ship. A third-person, EVE-style camera orbits it within a limited zoom range. The four laser mounts (front, rear, left, right) remain and you choose which one fires; you no longer need to switch views to see behind you. RULES records this as a deliberate difference.

**Presentation only:** 3D models, the HUD, the menu UI, sound, and rendering at display rate between 12 Hz ticks. Optional assists (target brackets, edge arrows) never change the sim.

## Starting point: a clean room from the private recreation

The faithful TypeScript recreation in the owner's private `recreations` repo is the *baseline*: it is read only by the spec-and-verify role, never copied. The Godot game is written only from documents in `docs/`, as `create-retro-game` prescribes.

| Role | Reads | Writes |
| --- | --- | --- |
| Spec and verify | The baseline and the annotated original source | `docs/RULES.md` (mechanics in our own words, message *purposes* instead of text), the distinctiveness brief, parity and overlap reports |
| Designer | RULES and the design docs | GDD (title, names, setting, the new galaxy and market), wireframes, art bible, UI design |
| Implementer | Only `docs/` and the knowledge documents beside the code | Rust, GDScript, scenes, tests |

**What RULES covers.** Every state, formula, threshold and timing the baseline implements: the flight model and its damping, the universe rotation, docking checks, sun heat, the AI's decisions, laser hit tests, missiles and E.C.M., damage and shields, spawning, legal status, ranks, and the order of random draws. It describes the galaxy generator and the market only as *structure* ("each system has an economy from 0–7 that sets…"), with no seeds, tables or names.

**What the designer creates new.** A galaxy generator with its own algorithm and seeds and its own name syllables; a market of our own goods and numbers; every name and message, written to RULES' purposes and length budgets.

**Ship stats** (energy, speed, laser power, missiles, bounty, target size) are rule numbers, which `create-retro-game` keeps by default. They are retuned too: the designer sets new values in the GDD, and the data-swapped baseline used for parity gets the same new values.

**Parity without the original data.** The verify role makes a scratch copy of the baseline, swaps its galaxy, market and text for the new ones, and records traces from it: inputs per tick plus a state hash. The Godot sim must reproduce those traces. That proves the mechanics match while nothing of the original's data enters the public repo.

## Architecture

The game is two layers that talk one way: a **sim** that knows nothing about nodes, frames or meshes, and a **presentation** that reads the sim and makes it look good. The presentation never writes to the sim; input reaches the sim only through a per-tick input record, and docked actions only through use-case commands that validate as RULES says.

**The sim** is Rust with no Godot dependency: universe, pilot, the bubble of up to 13 objects, flight, AI, market. It advances only when `tick(input)` is called and draws random numbers from one injected generator in the order RULES gives. Because nothing in it touches Godot, the same crates run headless in tests, in parity replays and, later, in a server.

**The loop** lives in one Rust class registered with Godot, `SimHost` (a `Node`):

1. Each frame, read Godot's input actions into an `InputRecord`: held actions plus a queue of presses.
2. Add `delta` to an accumulator; while it holds 1/12 s, keep the bubble's state as `previous`, run `tick()`, and collect the events it emitted.
3. Hand the presentation `previous`, `current`, the events (as Godot signals) and `alpha = accumulator × 12`. It lerps positions and slerps orientations, so 12 Hz logic looks smooth at 60–240 fps.

**Determinism.** The sim uses `f64` and only `+ − × ÷` and `sqrt` in rule code, plus the small set of functions RULES names, so a replay gives the same state on every platform. Random numbers come only from the sim's own seeded generator.

**Events** are how the art learns about gameplay: `laser_fired(slot)`, `missile_launched(slot)`, `hit(slot, shield)`, `exploded(slot)`, `ecm`, `area_blast`, `docked`, `launched`, `hyperspace_started`, `ambushed`, `message(id)`. Turrets, bay doors, flashes and sounds all key off these. Slot 0 is the player, so the player's own ship animates the same way.

**Hybrid, later.** Multiplayer moves `tick()` to a headless server binary built from the same crates; the client keeps the sim for prediction and smoothing. Nothing in the single-player design may assume the sim lives in the same process as the picture: the presentation reads snapshots and events, never the sim's internals.

**Coordinates.** As in the original, the sim is player-centred: your ship sits at the origin, always facing forward, and the universe moves and rotates around it.

- Sim axes are x right, y up, z forward (left-handed). Godot is right-handed with −Z forward, so positions map as `Vector3(x, y, -z) * UNIT_M`, and orientations get the same z flip.
- `UNIT_M = 0.2` m per sim unit. Each model is scaled on import to fill its type's target box (within about 25%), so a hit in the sim also looks like a hit.
- The planet and the sun are drawn as **scaled impostors**: beyond 2 km they are placed at 2 km along their true direction and scaled down by the same factor, so their angular size is exact and the depth buffer stays sane.

### The camera

The camera orbits your ship, EVE-style. Because the ship never moves or turns in the scene, the orbit is simple; what needs care is making the view feel anchored in space.

- **Space-anchored orbit (default).** The camera holds its direction in space, not relative to the ship. Each tick the sim rotates the universe by our roll and pitch; the camera's orbit direction is rotated by the same amount, so when you turn, the ship swings under a steady camera and the stars hold still, as in EVE.
- **Follow (option).** The camera eases back behind the active laser mount over about 1.5 s whenever you stop orbiting it. Closer to a classic chase view.
- **Zoom range.** From 1.5× to 5× your ship's length (90–300 m with the Cheetah stand-in), default 2.5×. Field of view 60°.
- **Mounts.** `1`–`4` choose the active laser mount (front, rear, left, right), and the camera swings to look along it. Lasers fire only from the active mount, as only the current view's laser fired in the original.
- **Aiming.** The original hit test is a cylinder around the mount's axis. The HUD draws that axis as a reticle at range and marks any ship inside the cylinder as *in line of fire*. Without that mark, aiming from behind the ship would be guesswork.
- **Obstacles.** If the station or a ship comes between the camera and your ship, the camera pulls in until it is clear.

Docked, a second camera shows the hangar scene.

### Project layout

The source is layered as in [A hundred and fifty diagrams before breakfast](https://icelander.net/v1/processes/a-hundred-and-fifty-diagrams-before-breakfast). Dependencies point inward only: presentation → use cases → features → capabilities. Infrastructure implements interfaces (Rust traits) that the inner layers own, and hosting wires the implementations in. Capabilities depend on nothing further out. Domain names repeat across layers: `market` is a capability, `trading` the feature built from it, and buying cargo at a station a use case.

```
games/lodestar/
  README.md
  docs/                     # create-retro-game's documents: PROVENANCE, RULES, GDD, DESIGN, ART-BIBLE,
                            # UI-DESIGN, TEST-PLAN
  Cargo.toml                # the Rust workspace, and the lodestar-core crate (src/lib.rs)
  project.godot             # the Godot project (res:// is this folder), Forward+
  lodestar.gdextension      # loads the hosting crate's library
  src/
    lib.rs                  # lodestar-core: use_cases, features and capabilities, no Godot
    journeys/               # journey documents, once a journey is evidenced
    use_cases/              # a pilot's goals: coordinating code and its document side by side
                            # (fly in a system, which owns the 12 Hz tick; trade at a station; jump)
    features/               # behaviours built from operations, each with its feature document:
                            # trading, docking, hyperspace and the ambush, fuel scooping, law and bounties
    capabilities/           # reusable interfaces and operations: universe, market, pilot, flight,
                            # combat, ai, spawning, random
    infrastructure/         # lodestar-infrastructure: save files and settings on disk, behind
                            # traits the capabilities own
    presentation/
      bridge/               # lodestar-bridge: the Rust classes GDScript calls (SimHost, snapshots,
                            # commands), converting to Godot types; formatting only
      space/  ships/  hud/  ui/  audio/  text/   # Godot scenes and GDScript; text holds every
                            # message and label in one table
    hosting/
      godot/                # lodestar-godot: the GDExtension library; registers the classes and
                            # wires infrastructure into the sim
      server/               # later, for multiplayer: the headless authoritative server binary
  assets/                   # GLBs, textures, fonts, sounds (asset folders, not components)
  tests/                    # Godot scene tests and parity replays; Rust tests sit in their crates
```

**Rules for the layout:**

- Folders and files are `snake_case`, the Rust and Godot convention, where the essay's examples use C#'s PascalCase.
- An operation lives in the capability that owns it. A small set may share one file; a larger one gets an `operations/` folder. One action is `<name>_operation.rs` holding `NameOperation`; a group is `<name>_operations.rs` holding `NameOperations`.
- The crate boundaries enforce the outer rules: `lodestar-core` cannot see Godot, infrastructure or the bridge. Inside `lodestar-core`, a test parses every `use crate::` path and fails when capabilities reach out to features or use cases, or features to use cases.
- Presentation scripts reach the sim only through the bridge's `SimHost`; they may call a feature or capability command directly for a simple operation, as the essay allows.
- `journeys/` exists only once a journey has evidence. No folder is created empty, and no component is made of an asset folder.
- Feature, use-case and journey documents follow [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development): present tense, every statement marked. They link to `docs/RULES.md` for exact mechanics rather than restating them.
- Every folder with something architectural to say gets its `.dev/` diagrams from the repository's skills in `Meta/Agents/Skills/`, in the same commit as the code. Actors named by documents or diagrams get files in the repository's `Actors/`.

The layout is confirmed by the spike, which is the pilot: one feature end to end through every layer. Anything the spike shows to be wrong is changed here before more code follows.

## Ships

One model for now: the ACNX-7 Cheetah GLB takes the heavy trader and pirate role, and stands in for every other ship, including yours, until more models exist. Later models come from the same scripted-Blender pipeline and follow the same rig contract.

### What the Cheetah gives us

|  | ACNX-7 Cheetah |
| --- | --- |
| Size (L × span × H) | About 59 × 19 × 8 m; the heavy trader's target box at 0.2 m per unit is 67 × 38 × 19 m |
| Triangles | 35,280 |
| Moving parts | 3 turrets, 4 missile-bay doors, 4 missiles, 2 airbrakes |
| Rig data | glTF node extras: `kind` (turret, door, missile, brake) and `sign` |
| Material | One PBR material: base, ORM, normal, emissive (running lights) |
| Textures | WebP; base and normal 4096², ORM and emissive 2048², all on the second UV set |
| File | 6.7 MB (4.6 MB geometry, 2.1 MB textures) |
| Animation | None baked; the viewer drives the parts in code, which suits a game |

### Rig contract (every ship GLB)

- `static`: the hull. Forward +X, up +Y, as in the Cheetah; the import script turns this to Godot's −Z.
- Moving parts as separate nodes with pivots at their hinge, tagged with `extras.kind`: `turret` (yaw about local Y), `door`, `missile`, `brake` (as now), plus `rotate` (`axis`, `amount` in degrees) and `slide` (`axis`, `amount` in metres) for future ships.
- Marker empties to add to the Cheetah in Blender:
  - `muzzle_N`: laser origin, child of its turret.
  - `exhaust_N`: engine nozzle, pointing aft, `extras.radius` in metres.
  - `beacon_N`: blinking light, `extras.color`, `extras.pattern` (steady, blink, strobe), `period`, `phase`.
  - `launch_N`: where a launched missile or escape pod first appears (one per bay).
  - `mount_front`, `mount_rear`, `mount_left`, `mount_right`: where each laser mount's beam starts when this is the player's ship.
- Running lights stay in the emissive texture.
- Textures baked to the **first** UV set. Godot's standard material reads albedo, normal and ORM from it; the Cheetah's are on the second.
- One material per ship, named after the ship.

### Import into Godot

An `EditorScenePostImport` script (`ships/ship_import.gd`) runs on every ship GLB:

1. Reads the extras into a `ShipRig` resource (parts by kind, markers, limits). If glTF extras do not arrive as node metadata, the Blender script also writes `<ship>.rig.json`.
2. Rotates +X forward to −Z and scales the ship to its type's target box.
3. Builds an `ORMMaterial3D` with emission driven at runtime, and turns on mesh LODs.
4. Imports textures with VRAM compression (S3TC/BPTC on desktop) at 2048²; the 4096² sources stay in Blender.

### Stand-ins until more models exist

Every ship type the sim spawns uses the Cheetah, scaled to that type's target box and given a per-type tint and beacon colour, so the player can still tell police from pirates from traders. Its rig only animates parts a type would use (no missile bays on a type that carries no missiles). Non-ship objects get simple dedicated models early because a Cheetah-shaped cargo canister would read as wrong: station, missile, cargo canister, asteroid, escape pod.

| Sim type (role) | Target size (L × W × H) | Model now |
| --- | --- | --- |
| Heavy trader, pirate | 67 × 38 × 19 m | **Cheetah** |
| Player's ship, trader and bounty hunter | 26 × 51 × 10 m | Cheetah stand-in |
| Police interceptor | 19 × 19 × 6 m | Cheetah stand-in, police beacons |
| Small pirate fighters (two types) | 13–19 × 26 × 3–6 m | Cheetah stand-in |
| Alien mothership and its drones | 66 m and 14 m | Cheetah stand-in, alien tint (a distinct model is the first one worth adding) |
| Station | 64 m | Simple dedicated model |
| Missile, escape pod, cargo canister, asteroid | 6–30 m | Simple dedicated models |

## Other objects in space

Everything the sim can put in the bubble gets a 3D treatment, and so do the effects the original drew as lines and dots. Sizes and positions always come from the sim.

| Object | Built as | Driven by |
| --- | --- | --- |
| Station | GLB with the same rig contract: hull, docking slot with guide lights, launch-bay doors | Sim position and roll; slot lights chase inward while the docking computer is on |
| Planet | Sphere with a procedural surface shader: terrain noise, oceans, clouds on their own layer, atmosphere rim | System seeds: economy picks the palette (agricultural greener, industrial greyer), tech level sets night-side city lights, the original's two styles become a ringed world (meridian) or a large impact crater |
| Sun | Unlit sphere with animated granulation in HDR, a corona billboard, and the scene's only `DirectionalLight3D` | Sim position; colour picked from the system seed (presentation only) |
| Starfield | Procedural panorama sky per galaxy, with a galactic band; also feeds ship reflections | Galaxy number |
| Stardust | 300 points in a `MultiMesh` that streak with speed and swing with roll and pitch | Our speed, alpha and beta from the sim, as the original's dust did |
| Lasers | Additive glowing beams: ours from the active `mount_*` marker along its axis, theirs from `muzzle_N` toward us | `laser_fired` events; colour by laser type |
| Missiles | GLB with exhaust trail (ribbon mesh) and blinking seeker | Sim missile slots; lock and launch events |
| Explosions | Light flash, hull debris chunks in the ship's material, sparks, a shock ring | `exploded` event; lasts as long as the sim's explosion cloud |
| Area blast | Full-screen white flash, then every ship's explosion | `area_blast` event |
| E.C.M. | Pale blue shell pulse around us, missiles flare as they die | `ecm` event and the sim's E.C.M. timer |
| Launch | The station's bay tunnel with light rings rushing past, replacing the original's rectangles | `launched` event |
| Hyperspace and ambush jumps | Tunnel shader of stretched stars; an ambush tints it green and cuts it short | `hyperspace_started`, `ambushed` events |

The station stays the original's size relative to ships (64 m, about a Cheetah). A kilometre-scale station would look grander, but docking is checked against the sim's slot, so the art must match it.

## Animation

Every moving part is driven by something the sim knows, so the animation tells the player what a ship is doing. Nothing is a looping clip. Because you now watch your own ship all the time, it animates by the same rules and is the most-seen animation in the game.

The mechanism is the one the Cheetah viewer already uses: each ship has named **channels** (`turrets`, `bays`, `brakes`, `lights`…), each with a target from 0 to 1 and a rate. Every frame a channel eases toward its target (`v += (target − v) × (1 − e^(−rate × dt))`), and the rig poses its parts from the channel values. The viewer's rates (turrets 3.5, bays 2.2, brakes 3, lights 6) are good defaults.

| Part | Driven by (sim) | What it does |
| --- | --- | --- |
| Turrets: deploy | Other ships: hostile. Yours: condition red, or any laser fired in the last few seconds | Rise out of the hull (1.15 m), retract when calm |
| Turrets: traverse | Other ships: direction to you. Yours: the active mount's direction, or the missile target | Yaw at up to 90°/s within ±150°; park at 0° when calm |
| Muzzle flash | `laser_fired(slot)` | A turret flashes and recoils; the beam starts at its `muzzle_N` |
| Missile bays | `missile_launched(slot)` | Doors open (to 105°), missile slides out, the sim's missile appears at `launch_N`, doors close |
| Visible missiles | The ship's missile count | Hidden one by one as the count drops; on your ship this doubles as an ammunition gauge |
| Airbrakes | Speed falling, or docking computer on | Extend up to 55° |
| Running lights | Energy as a share of the type's maximum | Full at full energy; flicker below 25%; out when killed |
| Beacons | Pattern from the rig | Blink or strobe; police alternate red and blue |
| Engine exhaust | Speed and acceleration | Plume length and brightness scale with speed; a flare on acceleration; noise flicker |
| Shield hits (yours) | `hit(0, fore or aft)` | A brief shimmer over the front or back half of a shield shell around your ship |
| Station | Sim roll; docking computer on | Spins; slot lights chase inward |
| Hangar idle | Docked | Your ship drifts gently on its pad |

**Engine exhaust** is built per `exhaust_N` marker: a cone mesh with an additive, scrolling-noise shader for the plume, a bright core sprite at the nozzle that blooms, and, for your ship and the two nearest others, a small `OmniLight3D` that lights the hull. This also stays within the Compatibility fallback's per-object light limit.

Ship positions and orientations are never animated by the presentation: they come straight from the interpolated sim. No added banking or wobble in flight.

## Lighting, the sun and bloom

The sun's bloom comes from Godot's built-in glow (Forward+, and also in the Compatibility fallback), fed by an HDR sun. The rule that makes it work: only things meant to glow are brighter than 1.0, so the glow threshold picks them out and nothing else smears.

**Environment** (one `WorldEnvironment`):

- Background: the procedural star panorama, which also lights and reflects on hulls.
- Tonemapping: AgX (falls back to ACES), exposure 1.0.
- Glow on: HDR threshold 1.0, intensity about 0.8, additive blend, levels 2–6 so the sun gets a wide halo and small lights a tight one. The viewers' bloom (strength 0.55, radius 0.35, threshold 0.92) is the look to match.
- Ambient: very low, from the sky. Space should have hard light and deep shadow.

**Brightness ladder** (emission energy, so bloom is ordered by importance):

| Source | Energy | Bloom |
| --- | --- | --- |
| Sun surface | 30–40 | Huge halo that washes the screen near it |
| Explosions, area blast flash | 10–20, brief | Strong flash |
| Exhaust cores | 8–12 | Bright points at the nozzles |
| Laser beams | 6–8 | Glowing lines |
| Running lights, beacons | 4 (the viewers' value) | Small, crisp glints |
| Hulls, planet, HUD | Below 1 | None |

**The sun's light.** One `DirectionalLight3D` points from the sun's sim position. Shadows are on but limited to 400 m, so nearby ships self-shadow and cast onto each other. A ship in the planet's shadow (a ray-sphere test from the sim) gets its sun term faded out through a per-instance shader parameter, so night-side fights are lit only by engines and lights.

**Glare.** When the sun is on screen and not hidden behind the planet or a ship (the same ray tests), a 2D overlay adds a soft glare and a few lens ghosts along the sun-to-centre line. Its strength also rises with the sim's cabin temperature, so flying close to the sun to scoop fuel feels hot.

**The HUD never blooms.** It is drawn on a `CanvasLayer` after the 3D image, so instruments stay crisp.

**Quality presets** (Low / Medium / High): MSAA off / 2× / 4×; glow levels 3 / 5 / 6; shadows off / ships only / ships and station; texture size 1K / 2K / 2K; render scale 0.75 / 1.0 / 1.0.

## Keyboard controls

Two built-in layouts, both fully remappable: **Modern** (the default) for WASD hands, and **Classic**, which puts flight on the BBC Micro's keys for players who learned them. Both drive the same sim actions. The camera has its own keys in both, and the mouse can orbit and zoom too.

| Action | Modern (default) | Classic |
| --- | --- | --- |
| Pitch: dive / climb | `W` / `S` | `S` / `X` |
| Roll left / right | `A` / `D` | `,` / `.` |
| Speed up / slow down | `R` / `F` | `Space` / `/` |
| Fire lasers (active mount) | `Space` | `A` |
| Active mount: front / rear / left / right | `1`–`4` | `1`–`4` |
| **Camera orbit** | Arrow keys (or right-drag) | Arrow keys (or right-drag) |
| **Camera zoom in / out** | `+` / `−` (or wheel) | `[` / `]` (or wheel) |
| **Camera reset behind active mount** | `Home` | `Home` |
| **Camera mode: space-anchored / follow** | `\` | `\` |
| Target / fire / unarm missile | `Q` / `E` / `Z` | `T` / `M` / `U` |
| E.C.M. | `C` | `E` |
| Area blast | `B` | `Tab` |
| Escape pod | Hold `Backspace` 1 s | Hold `Backspace` 1 s |
| In-system jump | `J` | `J` |
| Docking computer on / off | `K` | `C` |
| Hyperspace / galaxy jump | `H` / `Shift`+`H` | `H` / `Shift`+`H` |
| Galactic chart / local chart | `G` / `L` | `5` / `6` |
| System data / market prices | `I` / `O` | `7` / `8` |
| Status / inventory | `V` / `Y` | `9` / `0` |
| Chart cursor, distance, home | Arrows, `Enter`, `Home` (on charts the arrows move the cursor) | Same |
| Pause menu | `Esc` (or `P`) | `P` (or `Esc`) |

**Function keys.** On the desktop nothing owns `F1`–`F10`, so Classic may also put the screens on them, as the 1984 keyboard did; the digit keys stay as an alternative.

**How input reaches the sim.** Everything is a Godot `InputMap` action. Held actions (pitch, roll, speed, fire) are sampled at each 12 Hz tick. One-shot actions (mounts, missiles, E.C.M., jump) are queued on key-down and consumed by the next tick, so a quick tap between ticks is never lost. Key repeat is ignored. Camera input is presentation only: it is read every frame and never reaches the sim.

**Rebinding.** Options → Controls lists every action with its keys; press a key to bind, with conflicts shown. Saved with the settings. The same action layer will take a gamepad later.

**Focus.** If the window loses focus mid-flight, the game pauses.

## HUD

The HUD carries the same information the original's dashboard did, but in a new layout built around a third-person view: it must not look like the original's bottom-third dashboard (a bar column on each side of a central scanner). The wireframe and UI-design phases settle the details; this is the starting concept.

```
+----------------------------------------------------------------------+
|                 [ message ticker: one line, fades ]                  |
|                                                                      |
|                     ( )  <- active-mount reticle at range            |
|        speed                [in line of fire]          roll arc      |
|        tape         ___/\___                           pitch arc     |
|          |         /  your  \                                        |
|          |         \__ship__/                                        |
|                                                                      |
|  .-------.                                         shield halves     |
| ( sphere  )  heading   missiles: o o o .           energy: [][][][]  |
|  '-------'   pip       ECM  SAFE                   heat: hull laser  |
|  scanner                                           fuel, altitude    |
+----------------------------------------------------------------------+
```

| Information | Shown as | Source in the sim |
| --- | --- | --- |
| Contacts in range | A small tilted 3D sphere, bottom left, with contacts and height lines; it turns with the camera | Bubble positions, at the range RULES gives |
| Heading to the planet, or the station in the safe zone | A pip on the sphere's rim, solid in front, hollow behind | Direction vector |
| Fore and aft shields | The two halves of a ring around a small ship icon | Shield values |
| Energy | Four cells | Energy, split as RULES gives |
| Hull and laser heat, fuel, altitude | Compact labelled gauges; heat and altitude pulse near their limits | Heat counters, fuel, planet distance |
| Speed | Vertical tape left of centre | Our speed |
| Roll and pitch rates | Two short arcs right of centre | Control rates |
| Missiles | A row of pips: armed, seeking, locked, spent | Missile count and state |
| E.C.M., safe zone | Small badges that light up | E.C.M. timer, safe-zone flag |
| Condition | Tint of the scanner sphere: calm, alert, danger, docked | Condition |
| Aim | Reticle on the active mount's axis at range; a ship inside the hit cylinder gets an *in line of fire* mark | Mount, hit test |
| Messages | One-line ticker, our own wording to RULES' message purposes | Message events |

**Look.** Dark translucent glass, thin rules and a monospace font in the Cheetah viewer's palette: text `#e4e4e7` on `#0b0c0f`, gold `#c9a25c` for frames and labels, warning red and calm cyan as the only other colours. Anchored to the screen edges, so the centre stays clear for your ship; scales from 1280×720 to ultrawide.

**Assists** (off by default): contacts coloured by kind, corner brackets with name and range on ships in view, edge arrows toward off-screen hostiles. No lead indicator: lasers are instant in the sim.

**Build.** One `Hud` scene of `Control`s, each instrument a small node with a custom `_draw()`; the scanner sphere is a tiny 3D `SubViewport`. Everything reads the interpolated sim state every frame, and shares a `Theme` with the menus.

## In-game UI

Every screen the original had becomes a panel in one consistent UI, with the same information and the same actions but new layouts, names and wording. It is driven entirely from the keyboard (the mouse works too). The look is the Cheetah viewer's panel style: dark glass, numbered gold eyebrows (`01 MARKET`), monospace figures.

**Out of the game**

- **Title:** a slow flyby of the Cheetah against a planet and the sun (the bloom showcase), with New pilot, Load pilot, Options, About (with the credit line `create-retro-game` requires).
- **Options:** graphics preset and individual settings, audio volumes, controls and rebinding, camera mode and default zoom, assists, HUD scale.
- **Pause** (`Esc`/`P`): Resume, Options, Controls, Quit to title. The sim is frozen while paused.

**Docked.** The background is a 3D hangar: your ship on its pad under hangar lights, which you can orbit with the camera keys. Fitted equipment shows on the model where the rig allows (missiles in the bays now; more mount points as models gain them), and the Equip panel's camera moves to where an item fits.

| Panel | Modern / Classic key | What it holds |
| --- | --- | --- |
| Launch | `Enter` on Launch / `1` | Plays the launch, then flight |
| Market: buy and sell | Market tab / `2`, `3` | Our goods: price, unit, available, in hold. ↑↓ to pick, ←→ or digits for quantity, `Enter` to trade |
| Equip | Equip tab / `4` | Items allowed at this tech level, prices, fitted state; a laser asks which mount |
| Galactic chart | `G` / `5` | Every system of the current galaxy, the cursor, the fuel-range circle, the selected system |
| Local chart | `L` / `6` | Systems in fuel range, with names and a travel line |
| System data | `I` / `7` | Economy, government, tech level, population, productivity, size, inhabitants, and the planet itself rendered and turning |
| Market prices | `O` / `8` | Prices here; also viewable in flight |
| Status | `V` / `9` | Pilot, present and target systems, condition, fuel, credits, legal standing, rank, equipment |
| Inventory | `Y` / `0` | Fuel, credits and cargo |
| Save pilot | Save tab | Named save, docked only |

**In flight** the charts, system data, prices, status and inventory panels cover the space view (the HUD stays), and the sim keeps running: reading a chart in a fight is still a risk.

**Saving.** Pilots are saved as named files under Godot's `user://` folder, with export to and import from a file so a pilot can move between computers. Dying restarts from the last saved or loaded pilot.

**Build.** A `ScreenHost` swaps panel scenes; each panel reads the sim and calls sim commands (`buy(item, qty)`, `fit(item, mount)`, `select_system(x, y)`) that validate exactly as RULES says. All words come from one text table in `text/`, written in the UI-design phase and checked with `overlap.py`.

## Desktop build

The game ships as a native desktop build. There is no web build in scope.

- **Engine.** Godot 4.7.x, pinned, with matching export templates; godot-rust (`gdext`) pinned to a version that supports it. The Rust toolchain is pinned in `rust-toolchain.toml`.
- **Targets.** Windows (x86-64), macOS (universal), Linux (x86-64). Each export bundles the `lodestar-godot` library built for that target.
- **Building.** `cargo build --release` builds the library; `godot --headless --export-release "<platform>"` exports the game. One script does both for each platform.
- **Saves and settings** live in Godot's `user://` folder.
- **Private while in development.** Builds are not distributed until release; the repository is public, as before.
- **Distribution** at release is decided in the publish phase (for example itch.io or a store), with the credit line `create-retro-game` requires.

## Testing

The sim is proven to match the baseline's mechanics by replaying data-swapped traces; the clean-room checks prove nothing of the original got in; everything visual is tested for loading, contracts and speed.

| Test | What it checks | How |
| --- | --- | --- |
| Unit tests | Every rule in RULES, as it is written | `cargo test` in the workspace; Godot scene tests run headless with `godot --headless -s tests/run.gd` |
| Layer test | Dependencies point inward only | A Rust test in `lodestar-core` that parses `use crate::` paths; the crate graph enforces the rest |
| Deferred-work gate | No `TODO`, `FIXME`, `HACK` or `XXX` comment, no `TODO/` folder | A test run by `cargo test`, as knowledge-driven development requires |
| Diagrams and actors | Every `.dev/` diagram and actor link is well-formed | `python3 Meta/Agents/Skills/validate_diagrams.py` from the repository root |
| Parity | The sim's mechanics match the baseline | The verify role, in scratch only, gives a copy of the TypeScript baseline our galaxy, market, ship stats and text, records scripted games (launch, trade, fight, dock, hyperspace, the ambush, death) as inputs plus a state hash per tick; Godot replays them and stops at the first differing tick. Differences are bugs unless RULES lists them as deliberate |
| Overlap check | No original text or names | `overlap.py` from `clean-room-rebuild` over `docs/` and `text/`, with the original's names as `--names`; must be clean before every push |
| Guard test | No original name ever slips in later | The hash list from `make_guard_hashes.py`, checked against every text file in CI; proven once by planting a name |
| Rig contract | Every ship GLB has its parts, markers and limits | The import script fails with a clear message; a test loads every ship scene |
| Camera | Orbit, zoom limits, obstacle pull-in, both modes | Scripted camera paths around the station and a ship |
| Busy-bubble benchmark | Frame rate in the worst case: 12 ships fighting near the sun, missiles, explosions, all effects | Scripted scene in a release build; 60 fps at 1920×1080 on High, M1 MacBook Air, Chrome |
| Desktop smoke | Each platform's export starts, loads the ships, ticks, saves and quits without errors | `--headless --quit-after` runs of each export in CI, where a runner for the platform exists |
| Visual review | No screen could be mistaken for the original's | Contact sheet of every screen and the HUD, per `create-retro-game` |

## Milestones

The work follows `create-retro-game`'s phases, each ending at a gate where you approve before the next starts. One technical spike runs alongside the early phases, because it uses only the Cheetah and our own code, so it can be pushed before any rules exist.

1. **Spike, the pilot (in parallel with phases 0–2).** The Rust workspace with `SimHost` ticking an empty bubble at 12 Hz through godot-rust; the Cheetah imported through the rig script (UV fix, compressed textures, parts moving), with exhaust, flying near a blooming sun under the orbit camera; desktop exports for the three platforms; the first `.dev/` diagrams and the layer and deferred-work tests. *Gate:* it runs on Windows, macOS and Linux; frame rate measured; the layout confirmed or changed.
2. **Phase 0, provenance.** `docs/PROVENANCE.md` inventories what the baseline holds that must change. *Gate:* you confirm the slug and folder.
3. **Phase 1, RULES.** The behaviour spec from the baseline, including the camera and mount changes as deliberate differences. *Gate:* overlap check clean; you approve.
4. **Phase 2, GDD.** Three title proposals, setting, every name, the new galaxy generator, market and ship stats. *Gate:* you choose the title and names.
5. **Phases 3–5, wireframes, art bible, UI design.** HUD, panels and flow, adapted from the skill's Spectrum grid to screen-relative layouts. *Gate:* contact sheet approved.
6. **Phase 6, implementation.** First the working base: the Rust sim from RULES, proven by parity replays, under a plain playable client (flight, combat, docking, trading). Then the HUD, panels, hangar and saving at full quality. Stand-in Cheetahs for every ship. *Gate:* the whole game plays end to end in a desktop build.
7. **Phase 7, testing.** Parity, clean-room checks, benchmark, the three platforms. *Gate:* you review the test plan's results.
8. **More models, then phase 8, publish.** Station, missile, canister, asteroid and pod models first, then the alien ship, then the rest; then the first public build. *Gate:* your explicit "publish".

The first push to `retro-games` contains only our own work: the spike's code and the Cheetah. RULES arrives in its own reviewed push, and nothing that holds original data ever does.

## Risks and open questions

The biggest design risk is now the camera: seeing all around your ship changes how fights play, which no other decision does.

| Risk | Effect | Mitigation |
| --- | --- | --- |
| The third-person camera shows what the original hid (ships behind you) | Fights get easier than the original's | Keep the rules and scanner as they are, play-test, and only then decide on retuning; any change is logged in the GDD and RULES |
| Aiming from behind the ship has parallax | Lasers feel inaccurate | Reticle on the mount's axis at range, and the *in line of fire* mark from the sim's own hit test |
| The original's title and its ship and alien names are protected | Cannot publish under them | New title and names in the GDD; the overlap check and guard test enforce it |
| Every ship is a Cheetah for now | Hard to tell ships apart | Per-type scale, tint and beacons; the alien ship and the non-ship objects are the first new models |
| `create-retro-game`'s tools (template, contact-sheet renderer, parity kit) are TypeScript | They don't apply directly to a Rust and Godot game | The parity kit compares JSON traces, so the Rust sim only has to write the same format; contact sheets come from Godot screenshots |
| godot-rust lags a Godot release | The engine can't be upgraded when wanted | Pin both; upgrade together, after `gdext` supports the new version |
| The layered layout is new to a Godot and Rust game | Folders that fit the essay's C# examples may fit a game badly | The spike is the pilot; the layout is changed before more code follows |
| Cheetah textures are on the second UV set | Textures map wrongly in Godot | Re-bake to UV0; checked in the spike |
| glTF extras may not arrive as node metadata | Rigs don't load | Sidecar `<ship>.rig.json` from the Blender script |
| Glow in the Compatibility fallback is weaker than the viewer's bloom | The sun looks flat on old GPUs | Forward+ is the default; tune the fallback in the spike |
| JavaScript and Rust maths can differ in the last bit | Parity traces drift | Hash values rounded to 6 decimals; investigate at the first differing tick |

**Decided** (8 Nov): Cheetah only, in the heavy trader and pirate role; original galaxy, market, text and names replaced before the first push; public repo, builds private until release; the game lives in `retro-games`; you always see your ship, EVE-style, with limited zoom; working title LodeStar, slug `lodestar`; ship stats retuned; 8 galaxies of 256 systems; camera space-anchored by default, with follow as an option and a zoom range of 1.5× to 5× the ship's length.

**Decided** (8 Nov, later): the sim in Rust, presented through Godot 4 with godot-rust; desktop first and only, with the web build removed from the project's scope; hybrid, so a later multiplayer server can run the same sim; the source layered after the diagrams essay; the first deliverable is a working base that plays like the original, built from RULES.

## Sources

- The `recreations` repo (private): the baseline's README and source.
- The [`retro-games` repo](https://github.com/david-brandt-the-icelander/retro-games): `README.md`, `.claude/skills/create-retro-game/SKILL.md`, `AGENTS.md`, `Meta/Agents/Skills/`.
- The Cheetah: `ACNX-7_Cheetah_viewer.html` (embedded GLB inspected) and the owner's comparison images.
- [endoflife.date: Godot](https://endoflife.date/godot) (4.7.2 current).
- [A hundred and fifty diagrams before breakfast](https://icelander.net/v1/processes/a-hundred-and-fifty-diagrams-before-breakfast) and the [processes](https://github.com/david-brandt-the-icelander/processes) repository: the layered layout, `.dev/` diagrams and actors.
- [Knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development): the status marks for feature, use-case and journey documents.
- [godot-rust](https://godot-rust.github.io/) (`gdext`): Rust bindings for Godot 4 through GDExtension.

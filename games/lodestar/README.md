# LodeStar (working title)

A space trading and combat game for the desktop (Windows, macOS, Linux), with its rules in Rust and its picture in Godot 4: the mechanics of a 1984 BBC Micro classic, with its own galaxy, market, names and text, a third-person camera that always shows your ship, and modern 3D art.

**Status:** design approved (overall design, rules, GDD, art bible, UI design). The working base's sim is built from `docs/RULES.md`: the universe, trading and equipment, saving, flight, combat and the ship AI, spawning, docking, hyperspace, death and the escape pod, driven by a 12 Hz tick through every game mode, with 409 tests. A plain but complete playable client runs on top of it: the title, the docked hub (market, equipment, charts, system data, pilot and saving, hold), flight with a plain HUD and every flight action, fights, docking, hyperspace, death and loading, with every ship a Cheetah stand-in. LodeStar is the working title and `lodestar` its slug.

- [docs/DESIGN.md](docs/DESIGN.md): the overall design: the sim and presentation split, the camera, ships and their rig contract, animation, lighting and bloom, controls, HUD, UI, the desktop build, the layered source layout, testing and milestones.
- [docs/RULES.md](docs/RULES.md): the clean-room behaviour spec (phase 1, approved): universe and trade, flight, combat and AI, game modes and messages, tick by tick, with the owner's decisions and the deliberate differences they make.
- [docs/ART-BIBLE.md](docs/ART-BIBLE.md): the visual and audio identity: pillars, palette, ships and materials, light and bloom, space, effects, camera, type and icons, sound, and how every screen differs from the original's.
- [docs/UI-DESIGN.md](docs/UI-DESIGN.md): tokens, layout, components, the flight HUD element by element, every screen and the flow between them, text budgets and accessibility.
- [docs/contact-sheet.png](docs/contact-sheet.png) and [docs/screens/](docs/screens/): example screens over real-time renders of the Cheetah model.

The game is made with the [`create-retro-game`](../../.claude/skills/create-retro-game/SKILL.md) skill: its clean-room documents (`PROVENANCE`, `RULES`, `GDD` and the rest) arrive in `docs/` phase by phase, each after the owner's approval. Nothing taken from the original game, or from the private faithful recreation used as the baseline, is ever committed here.

The source follows the repository's agent conventions (`AGENTS.md`): a layered layout with `.dev/` architecture diagrams beside the code, actors in the repository's `Actors/`, and feature, use-case and journey documents under [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development). The layout is in [docs/DESIGN.md § Project layout](docs/DESIGN.md#project-layout).

## Develop

You need Rust 1.97 (pinned in `rust-toolchain.toml`) and Godot 4.7.2. From this folder:

```bash
cargo test --workspace     # the rules, the bridge's readouts, the pilot files, the layer and deferred-work gates
cargo build                # the GDExtension library Godot loads (lodestar.gdextension)
godot --path .             # play; or `godot -e --path .` for the editor
```

Godot has to import the project once (`godot --headless --path . --import`, or open the editor) before the first run.

### How to play (Modern keys)

| | Keys |
| --- | --- |
| Title | ↑↓ and `Enter`: Continue, Load pilot (type a name), About, Quit |
| Docked | `1`–`7` or `Q`/`E`: the Market, Equip, Galaxy, Local, System, Pilot and Hold tabs; `L` launch; `Esc` pause |
| Market | ↑↓ pick, ←→ quantity (`Shift` ×10, keypad digits type it), `B` buy, `N` sell |
| Equip | ↑↓ pick, `Enter` buy; a laser asks for a mount (←→ or `1`–`4`, `Enter`) |
| Pilot | `S` save under a name (`Enter` saves) |
| Fly | `W`/`S` dive and climb, `A`/`D` roll, `R`/`F` faster and slower, `Space` fire, `1`–`4` the active mount (fore, aft, port, starboard) |
| Weapons | `Q` target a Dart, `E` fire it, `Z` unarm; `C` scrambler; `B` nova charge; hold `Backspace` a second for the lifeboat |
| Travel | `J` hop; `K` auto-berth; `H` jump to the system nearest the chart cursor; `Shift`+`H` Reach jump |
| Panels in flight | `G` Reach chart, `L` local chart, `I` system, `O` prices, `V` pilot, `Y` hold; the same key or `Esc` closes |
| Charts | arrows move the cursor (`Shift` ×8, or click), `Enter` select and show the distance, `Home` back to you |
| Camera | arrows or right-drag orbit, `=`/`-` or the wheel zoom, `Home` behind the active mount, `\` space-anchored or follow |
| Pause | `Esc` or `P`: resume, auto-centre and damping toggles, quit to title |

To dock, fly into the Spindle's glowing slot nose on, with the slot level with your wings: a miss at speed 5 or more is fatal, a slower one only bumps you. The auto-berth docks at once from anywhere in the safe zone.

### Scripted runs

`godot --path . -- --shot=out.png --frames=150` saves a screenshot after 150 frames and quits; `--yaw=` and `--zoom=` place the orbit camera. `godot --path . -- --script=@shots --shots=<folder>` plays a scripted game and saves a screenshot of every screen, and `godot --headless --path . -- --script=@smoke` is the headless smoke test (exit code 0 when every check passes). The script steps are listed in [src/presentation/game/script_runner.gd](src/presentation/game/script_runner.gd).

Exports and their status are in [src/hosting/godot/desktop-build.md](src/hosting/godot/desktop-build.md). Before finishing a change, also run `python3 Meta/Agents/Skills/validate_diagrams.py` from the repository root.

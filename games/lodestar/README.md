# LodeStar (working title)

A space trading and combat game for the desktop (Windows, macOS, Linux), with its rules in Rust and its picture in Godot 4: the mechanics of a 1984 BBC Micro classic, with its own galaxy, market, names and text, a third-person camera that always shows your ship, and modern 3D art.

**Status:** design (overall design, rules, art bible, UI design; the GDD awaits approval) and the spike: the sim ticks at 12 Hz inside Godot, and the Cheetah flies under the orbit camera near a blooming sun. Nothing is playable yet. LodeStar is the working title and `lodestar` its slug; the GDD phase confirms the title. The first deliverable is a working base: the Rust sim built from `docs/RULES.md` under a plain playable client.

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
cargo test                 # the rules, the layer test and the deferred-work gate
cargo build                # the GDExtension library Godot loads (lodestar.gdextension)
godot --path .             # open the game; or `godot -e --path .` for the editor
```

`godot --path . -- --shot=out.png --frames=150` saves a screenshot after 150 frames and quits; `--yaw=`, `--pitch=` and `--zoom=` place the orbit camera. Exports and their status are in [src/hosting/godot/desktop-build.md](src/hosting/godot/desktop-build.md). Before finishing a change, also run `python3 Meta/Agents/Skills/validate_diagrams.py` from the repository root.

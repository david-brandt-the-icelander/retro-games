# Lodestar (working title)

A space trading and combat game in Godot 4 for the web: the mechanics of a 1984 BBC Micro classic, with its own galaxy, market, names and text, a third-person camera that always shows your ship, and modern 3D art.

**Status:** design (overall design, art bible, UI design). Nothing is playable yet. `lodestar` is a working slug; the GDD phase chooses the title.

- [docs/DESIGN.md](docs/DESIGN.md): the overall design: the sim and presentation split, the camera, ships and their rig contract, animation, lighting and bloom, controls, HUD, UI, web hosting, testing and milestones.
- [docs/ART-BIBLE.md](docs/ART-BIBLE.md): the visual and audio identity: pillars, palette, ships and materials, light and bloom, space, effects, camera, type and icons, sound, and how every screen differs from the original's.
- [docs/UI-DESIGN.md](docs/UI-DESIGN.md): tokens, layout, components, the flight HUD element by element, every screen and the flow between them, text budgets and accessibility.
- [docs/contact-sheet.png](docs/contact-sheet.png) and [docs/screens/](docs/screens/): example screens over real-time renders of the Cheetah model.

The game is made with the [`create-retro-game`](../../.claude/skills/create-retro-game/SKILL.md) skill: its clean-room documents (`PROVENANCE`, `RULES`, `GDD` and the rest) arrive in `docs/` phase by phase, each after the owner's approval. Nothing taken from the original game, or from the private faithful recreation used as the baseline, is ever committed here.

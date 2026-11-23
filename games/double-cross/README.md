# Double Cross

A spy-trap party game in Godot 4, for the browser. Up to eight agents, each on their own computer, search furniture for four pieces of intel, rig furniture and doorways with traps, and race to the extraction door. Anyone eliminated keeps watching every surviving agent in spectator mode.

Play at [icelander.net/games/retro/double-cross](https://icelander.net/games/retro/double-cross/) (a sign-in with icelander.net is needed, as for every game there). Matches with friends start from the [multiplayer page](https://icelander.net/games/multiplayer/), which opens the game for everyone with `?match=ID`. **Practise alone** works without one.

## Playing

- **Modes**: *Last Agent Standing* (the last agent alive wins, or the first to extract with all four pieces of intel) and *Co-op Teams* (two teams pool their intel, can't hurt each other and don't trigger each other's traps; any member can extract once the team's living members hold all four).
- **Maps**: The Safehouse (2 agents), The Embassy (4), Grand Hotel Meridian (6), Polar Station Kappa (8). Doors, room names and furniture come from a seed the host picks for each match.
- **Traps**: Proximity Mine and Nerve Gas on furniture; Tripwire Charge and Shock Plate on doorways. Each has a counter-gadget hidden in the furniture (Defuse Kit, Gas Mask, Wire Cutters, Rubber Gloves), used up when it saves you.
- **Controls**: WASD or arrows to move, E search, F set the selected trap, 1–4 / Q / mouse wheel pick a trap, Space or click punch, Tab changes the spectator layout. Gamepads work too.
- Only the room you're in is lit, and other agents are visible only there or in its doorways. Teammates show on the minimap.

## How it works

The host (the lowest slot in the match) is authoritative. Every browser moves its own agent and sends where it is; searches, traps and punches go to the host as requests (`rq_*`), and the host sends back what happened (`ev_*`). Only the host's events are accepted (`godot/scripts/net.gd`). The host alone knows where the intel and traps are, so the match ends if the host leaves.

In the browser the messages travel through the games hub's match relay, `/games/multiplayer/match/{ID}`, the same one Rally, Shatterbelt and Hivestorm use. On the desktop the same messages travel over ENet: one player hosts and the others join by IP address.

## Files

| Path | What it is |
|---|---|
| `godot/` | The Godot 4.7 project (Compatibility renderer). Everything is built from primitives in code: no art or sound files. |
| `godot/scripts/net.gd` | Sessions (relay, ENet, practice), the briefing room, and the message layer. |
| `godot/scripts/maps.gd` | The maps, their themes, the trap and item tables, and the seeded layout generator. |
| `godot/scripts/game.gd` | One match: the host's rules and every browser's camera, input and visibility. |
| `godot/scripts/world_builder.gd`, `player.gd`, `hud.gd`, `spectator.gd`, `fx.gd` | The level, the agents, the HUD, the spectator grid, the effects. |
| `godot/web_shell/shell.html`, `boot/boot.ts`, `web/` | The page around the game and its loading screen. |
| `godot/tests/` | Godot tests: every map over 200 seeds, and the message layer's rules. |
| `worker/index.ts` | The Worker: the page for signed-in players, and the engine joined from its parts. |
| `test/` | Tests of the Worker. |

## Commands

| Command | What it does |
|---|---|
| `npm test` | Type-check and test the Worker. |
| `npm run test:godot` | The Godot tests (needs `godot` 4.7.2 on the PATH). |
| `npm run build` | The web export into `dist/games/retro/double-cross/` (needs Godot 4.7.2 with its web export templates; set `GODOT` to its path). |
| `npm run dev` | Build and run the Worker locally with wrangler. |
| `npm run deploy` | Test, build and deploy. Nothing deploys from GitHub, so this is how it goes live. |

Desktop testing flags, after `--`: `--host`, `--join=IP`, `--solo`, `--match=ID --relay=ws://HOST:PORT`, `--name=NAME`, `--map=ID`, `--mode=lms|teams`, `--autostart=N`, `--spectate`, `--bot`, `--quit-after=S`, `--shot=FILE --shot-at=S`, `--selftest`.

## Not yet

No sound, no touch controls, and no joining a match already under way (a late arrival waits in the briefing room). See `.dev/backlog.json` and `.dev/limitations.json`.

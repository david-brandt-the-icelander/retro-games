# Pilot

**Kind:** person in a role
**Evidence:** `games/lodestar/src/use_cases/fly_in_system/mod.rs` (`InputRecord`, `HeldActions`, `Press`), `games/lodestar/src/presentation/bridge/src/sim_host.rs` (`held_actions`, `SimHost::press` and the other press methods), `games/lodestar/src/presentation/game/game.gd` (`handle_key`), `games/lodestar/project.godot` (`[input]`: the flight, weapon, travel, screen, pause and camera actions)

## What they want from the system

- To fly their ship in a star system and choose which laser mount fires, fight, trade at stations, jump between systems and keep their progress by saving: [Fly in a system](../games/lodestar/src/use_cases/fly_in_system/fly_in_system.md).
- To see and drive all of it from the keyboard: [the game scene and its keys](../games/lodestar/src/presentation/game/game.md), [the panels](../games/lodestar/src/presentation/ui/ui.md), [the HUD](../games/lodestar/src/presentation/hud/hud.md).
- Goal by goal (start playing, trade, buy equipment, save, launch, fight, jump, dock, abandon ship): [LodeStar's use cases](../games/lodestar/src/use_cases/fly_in_system/.dev/use-case.json).
- Over a session: a trading run, and losing the ship ([LodeStar's journeys](../games/lodestar/.dev/user-journey.json), `trading-run` and `losing-the-ship`).

## How they reach it

The LodeStar desktop game, with a keyboard and mouse.

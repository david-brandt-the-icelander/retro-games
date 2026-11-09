# The in-system jump (the hop)

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the tick in the [fly-in-a-system use case](../../use_cases/fly_in_system/fly_in_system.md)

## What this is for

A new system's planet is several far units away. With nothing else about, the pilot hops a far unit at a time towards it, free and as often as they like, until the planet or the sun is close ahead or company arrives. The mechanics are in [RULES B.13](../../../docs/RULES.md#b13-in-system-jump).

## What it does

- ✅ `in_system_jump` refuses when any ship, missile or drone is present, counting the bubble minus two fixed slots minus rocks, escape pods and canisters ([RULES D.14](../../../docs/RULES.md#d14-quirks-and-edge-cases-baseline-behaviour-that-parity-depends-on) item 13), in the safe zone, or in the Deep.
- ✅ It refuses when the planet or the sun is ahead (z ≥ 0) and within 2 L on every axis; a body behind never blocks.
- ✅ Otherwise the planet's and the sun's z fall by one far unit; rocks, canisters and pods stay where they are relative to the pilot ([RULES B.23 Q-B17](../../../docs/RULES.md#b23-quirks-reproduce-these)); C becomes 1 and the spawn delay 0. No fuel or energy is used and there is no limit on repeats.
- ✅ Because C is 1, the tick's chores bring it to 0 and run the periodic spawn at the end of that same tick, and the next tick recharges and may place the station.
- ✅ Every object's on-screen, on-scanner and firing flags are cleared, as reselecting the flight view does ([RULES B.20](../../../docs/RULES.md#b20-views-mounts-and-the-notional-view)).
- ⚠️ On `Jumped` the presentation clears the bottom line (the destination and out-of-range notices); on `Refused` it plays the long beep (S6, [RULES D.11](../../../docs/RULES.md#d11-sound-cues)).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| Another ship is about | The long beep; nothing moves | Deal with it, or wait for it to leave | ✅ |
| The planet or sun is close ahead | The long beep | Fly the rest of the way | ✅ |

## What it deliberately doesn't do

- It draws no random number.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`InSystemJump`, `in_system_jump`).
- Uses: the bubble, cockpit, ships and space capabilities; the [spawning](../spawning/spawning.md) feature's `SpawnDelay`.

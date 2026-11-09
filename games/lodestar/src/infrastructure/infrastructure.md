# Infrastructure

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the engineer who wires the sim to the machine it runs on, and through it the [pilot](../../../../Actors/pilot.md)

## What this is for

The rules own their interfaces and never touch a disk ([DESIGN § Project layout](../../docs/DESIGN.md#project-layout)). This crate, `lodestar-infrastructure`, implements those interfaces on the real machine. So far that is one: the [saving feature's](../features/saving/saving.md) `PilotStore`, as files, so a pilot saved at a station is still there next time the game starts ([RULES A.8](../../docs/RULES.md#a8-saving-and-loading)).

## What it does

### Pilot records as files

- ✅ `PilotFiles` keeps one text file per saved pilot, `<NAME>.pilot`, in one folder; the Godot host points it at `user://pilots/`. The record's format, and whether a record read back is accepted, are the saving feature's; this crate only stores and fetches the text.
- ✅ A write goes to a `.partial` file first and is renamed into place, so a crash never leaves half a record; the folder is made on the first write; a second save under the same name replaces the first (RULES A.14 item 19).
- ✅ Only a name a record may hold (1 to 7 of A–Z and 0–9) reaches the disk, so no name can point outside the folder; any other name reads as missing and writes nothing.
- ✅ `names()` lists the pilots that have a record, sorted, ignoring every other file; a missing folder has none.
- ✅ Saving and loading through files gives exactly what saving and loading through the in-memory store gives.
- ⚠️ A pilot can be exported to a file of their choice and imported from one, so a pilot moves between computers ([DESIGN § In-game UI](../../docs/DESIGN.md#in-game-ui), Saving).
- ⚠️ Settings (key bindings, graphics, audio, camera and interface options) are kept in `user://` beside the pilots.

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The folder cannot be written (full disk, permissions) | The file is not written; the save in play stands | Free the disk or fix the permissions and save again | ✅ |
| A record file was edited or damaged | Loading it is refused by the saving feature's check | Load another pilot, or restore the file | ✅ |

## Where it lives

- Code: [`src/pilot_files.rs`](src/pilot_files.rs) (`PilotFiles`, with its tests), [`src/lib.rs`](src/lib.rs).
- Used by the [presentation bridge](../presentation/bridge/bridge.md); shown in the game's [component diagram](../../.dev/component-diagram.json).

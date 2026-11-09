# Saving and loading a pilot

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

A pilot's ship, cash, cargo and record are worth something only if they last. The pilot saves at a station under a name, and dying sends them back to that save, so every launch risks what they have earned since. This feature keeps the two copies of the pilot, takes the name, writes the record in LodeStar's own format and decides whether a record read back is accepted. The exact mechanics are in [RULES A.7.3](../../../docs/RULES.md#a73-two-copies), [A.8](../../../docs/RULES.md#a8-saving-and-loading), [D.6.12](../../../docs/RULES.md#d612-name-prompt-title-load-and-save) and [D.12](../../../docs/RULES.md#d12-what-is-saved-and-when); this document says what LodeStar does of them and how its format looks.

## What it does

### The two copies

- ✅ The game holds a playing pilot and a saved pilot; at power-on both are the start pilot (`Pilots::new`, RULES A.7.3).
- ✅ Death puts a copy of the saved pilot in play and keeps nothing of the dead one; before any save that is the start pilot (`Pilots::on_death`).
- ✅ The title makes the playing pilot a copy of the saved one whether or not the pilot chose to load (`Pilots::restore`, RULES D.3.1 step 3).

### The name

- ✅ The name prompt takes letters A–Z, stored in capitals, and digits, up to 7; further characters and every other key are ignored; delete removes the last character; confirm returns the typed name, possibly empty; cancel returns an empty name (`NamePrompt`, RULES D.6.12).
- ✅ A name that arrives as text, from a text field or a file, goes through the same rules as if it were typed (`validate_name`): `Ace 1!` becomes `ACE1`.

### Saving

- ✅ Saving does nothing unless the pilot is docked (RULES A.8.2 step 1).
- ✅ An empty or cancelled name saves nothing.
- ✅ Otherwise the playing pilot takes the name, the saved pilot becomes a copy of it, and the record is written under that name, replacing any record already there (RULES A.14 item 19).
- ✅ The record holds every field of RULES A.7.1 and a check value, and no flight state (RULES A.8.1, D.12).

### Loading

- ✅ An empty name loads the saved pilot's own name (RULES A.8.3 step 2).
- ✅ An accepted record becomes the saved pilot and then the playing one; a missing or rejected record changes nothing, and the playing pilot is still reset to the saved one (RULES A.8.3 steps 3 to 5). The error says why, and the caller shows no message for it, as RULES D.3.1 says.
- ✅ Fields missing from a record take the start pilot's values before the check is computed, so a record without a field loads only if the field held its start value when the record was written. The start pilot given to `Pilots::new` is the one used, so its start market (RULES A.9.7) fills a missing market.
- ✅ The stored galaxy state is used as saved, never rebuilt from the galaxy number.

### The record

- ✅ A record is UTF-8 text: a header line `LODESTAR PILOT 1`, then one `key value…` line per field, then `check` and eight hex digits. `encode` writes the fields in a fixed order with single spaces; `decode` reads them in any order, with any blank lines, spaces, tabs or Windows line ends.

  | Key | Values |
  | --- | --- |
  | `name` | 1..7 of A–Z, 0–9 |
  | `position` | x and y, 0..255 |
  | `galaxy-state` | three words of four hex digits (the six bytes of RULES A.3.1) |
  | `galaxy` | 0..7 |
  | `cash` | tenths of a credit, 0..18446744073709551615 |
  | `fuel` | 0..70 |
  | `lasers` | four values, each 0, 15 or 143 |
  | `hold` | 0..255 |
  | `cargo` | 17 values, 0..4294967295 |
  | `ecm`, `fuel-scoop`, `area-blast`, `energy-booster`, `auto-dock`, `galaxy-drive`, `escape-pod` | `yes` or `no` |
  | `missiles` | 0..4 |
  | `legal` | 0..255 |
  | `availability` | 17 values, 0..63 |
  | `market-byte` | 0..255 |
  | `kills` | 0..65535 |
  | `check` | CRC-32 (the zip and PNG one) of the canonical record, every line before `check` as `encode` writes it, rebuilt from the values read; hex digits in either case |

- ✅ A record is accepted only when every one of these holds; otherwise it is rejected and loading changes nothing (deliberate difference 11, keeping RULES A.8.3 step 3):
  - the first non-blank line is the header, with version 1 (`NotARecord`, `UnsupportedVersion`);
  - every known field it has parses: the right number of plain decimal numbers (no sign, point or exponent) each within the range above, `yes` or `no`, a valid name, and a galaxy state of exactly six bytes; cargo and availability lists of exactly 17 entries (`Malformed`, with the line and key);
  - no field appears twice (`Duplicate`);
  - it has a check, and the check matches the values (`MissingCheck`, `CheckMismatch`).
- ✅ A line whose key LodeStar does not know is ignored, as a field a record format would ignore.
- ✅ The record format needs no library: `encode` and `decode` are written by hand, and the feature never touches the disk; a store behind the `PilotStore` trait reads and writes records by name (`MemoryStore` keeps them in memory).
- ⚠️ Infrastructure stores records as files in Godot's `user://` folder through `PilotStore`, one per name, and the Pilot tab exports a record to a file and imports one through `decode`, so an imported file is accepted or rejected exactly as a stored one (DESIGN § Saving, GDD § 8).
- ⚠️ The title's load question, the save action in the hub and the death sequence call `Pilots::load`, `Pilots::save` (with whether the pilot is docked) and `Pilots::on_death`; after the title, the system nearest the pilot's position becomes the current and selected system with distance 0, and the docked status screen shows (RULES A.8.3 step 6, D.3.1 step 5).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| No record has the typed name | Loading carries on with the saved pilot, no message | Type the name the pilot was saved under | ✅ |
| A record was edited by hand, cut short or damaged | It is rejected as if absent; the saved pilot is unchanged | Load another save, or play on from the saved pilot | ✅ |
| A record comes from a newer LodeStar with another version number | It is rejected as if absent | Load it in the LodeStar that wrote it | ✅ |

## What it deliberately doesn't do

- It does not read or write the baseline's records; only their accept and reject behaviour is kept (deliberate difference 11). Its check is not the baseline's (RULES A.8.4 allows any check with the same effect).
- It does not record a "last used" name: the baseline writes one and never reads it (RULES A.8.2 step 3).
- It never saves automatically or in flight.
- A value outside its field's range (fuel 71, galaxy 8, a laser value other than 0, 15 or 143) makes a record malformed even when its check matches, so a hand-made record can never put the sim in a state the rules do not allow.

## Where it lives

- Code: [`mod.rs`](mod.rs), [`name.rs`](name.rs) (`NamePrompt`, `NameKey`, `validate_name`), [`record.rs`](record.rs) (`encode`, `decode`, `decode_over`, `LoadError`), [`pilots.rs`](pilots.rs) (`Pilots`, `PilotStore`, `MemoryStore`, `SaveOutcome`); the pilot's fields are the [pilot capability](../../capabilities/pilot/mod.rs).
- Diagrams: [`.dev/class-diagram.json`](.dev/class-diagram.json).

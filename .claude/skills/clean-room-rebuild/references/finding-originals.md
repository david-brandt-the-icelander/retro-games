# Finding the original to compare against

The overlap check needs the original's text, and the inventory needs to know what the original's art, maps and code looked like. Keep everything you collect in a scratch directory outside the repo: it is a reference, never part of the published remake.

Platform add-on skills (e.g. **zx-spectrum-clean-room**) know how to extract text from that platform's files. Use one when it exists. Otherwise:

## Where originals live

| Kind of original | Where to look | What you get |
|---|---|---|
| BASIC games on home computers | Tape/disk images in platform archives; type-in listings in magazine and book scans on archive.org | The full program text: list it with an emulator or a detokenizer for that BASIC dialect |
| Machine-code games | Fan disassemblies (often on GitHub, many built with SkoolKit, da65, Ghidra or IDA); decompilation projects | Messages as string directives (`DEFM`, `DB`, `.byte`, `.text`, `.asciiz`) and the data tables |
| Any game, no disassembly | The binary itself: run a `strings`-style scan (printable runs; also try bit-7-terminated and length-prefixed strings) | Most messages, names and menu text |
| Arcade games | MAME driver notes, ROM-hacking wikis, The Cutting Room Floor | Text, level data descriptions |
| Instructions | Manual scans (archive.org, platform archives, gamesdatabase.org), magazine reviews | Manual text, which remakes often copy into "how to play" screens |
| Look and sound | Screenshots and longplay videos | What the title screen, sprites and tunes looked and sounded like, for the "would someone mistake this for the original?" test |

## Turning it into overlap references

- BASIC listing: save as plain text with line numbers. `overlap.py` treats files where most lines start with a line number as BASIC and pulls out the quoted strings.
- Disassembly: save the `.asm`/`.skool`/`.ctl` file. `overlap.py` picks up `DEFM`/`DEFB`/`DB`/`DM`/`.ASCII`/`.TEXT`/`.BYTE` lines with quoted strings.
- Manual or `strings` output: save as `.txt`. It is read as prose, and n-grams cross line breaks.
- Invented names: pass them with `--names` (single words are otherwise too short to flag).

## Credits and rights holders

Record the copyright line exactly as the game and manual print it, plus publisher, authors, year and any re-releases, in PROVENANCE.md. `legal-basis.md` explains how to trace the current owner from there.

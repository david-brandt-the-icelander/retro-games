# Where to find Spectrum originals

## Tape images, manuals, credits

- **Spectrum Computing** — `https://spectrumcomputing.co.uk/entry/<id>/`. Publisher, authors, year, re-releases, availability, downloads (`/pub/sinclair/games/<letter>/<File>.tap.zip` and `.tzx.zip`), instructions, inlays. Backed by ZXDB.
- **World of Spectrum** — `https://worldofspectrum.org/archive/software/games/<slug>`. Same catalogue, older mirror.
- **archive.org** — World of Spectrum mirrors, magazine scans (Crash, Your Sinclair, Sinclair User — useful for reviews quoting the game and for type-in listings).
- **gamesdatabase.org** — transcribed manuals.

The "Availability" values ("Available", "Distribution denied", "Distribution denied – still for sale", "MIA") describe the archive's hosting arrangement only.

## Fan disassemblies (machine-code games)

These are reverse-engineered, not original source, and come with no licence from the rights holder. Reading them to understand behaviour is fine; copying their text, data or code structure is copying the original.

- skoolkit.ca — Manic Miner, Jet Set Willy, Skool Daze, Back to Skool, Contact Sam Cruise, Hungry Horace.
- github.com/mrcook/zx-spectrum-games — Knight Lore, Alien 8, Atic Atac, Chaos, Tir Na Nog, Dun Darach, Spellbound, Knight Tyme, Stormbringer, Through the Trap Door, Dynamite Dan 2; plus mrcook's Jetpac, Lords of Midnight and Chuckie Egg repos.
- github.com/pobtastic/ultimate — Sabre Wulf, Lunar Jetman, Jetpac, Atic Atac (and others by pobtastic: The Hobbit, Way of the Exploding Fist, Trashman, Wheelie, Pssst).
- github.com/dpt/The-Great-Escape, github.com/simon-frankau/head-over-heels, github.com/santiontanon/netherearth-disassembly, github.com/ZXGuesser/chaos-disassembly, github.com/ataribaby42/zx-elite (128K Elite), github.com/nzeemin/skoolkit-game-revs (Saboteur), github.com/rusarh/exolon-esl, github.com/Paulie68000/ZXSpectrumHyperActive, Ritchie Swann's repos (3D Deathchase, Everyone's a Wally, Starquake).
- recompsoftware.com/platforms/zx-spectrum — running list of decomps and ports.

## Snapshots and other formats

- `.tap`, `.tzx`, `.sna` (48K): handled by `scripts/zx_basic_list.py`.
- `.z80`: compressed snapshot; load it in an emulator (e.g. Fuse) and `SAVE` the program to a `.tap`, or use Fuse's `listbasic` utility (`fuse-emulator-utils` package), which reads `.z80`, `.szx` and tape files.

## Finding the rights holder

1. Copyright line in the program and manual.
2. Spectrum Computing's authors/publisher fields and "Re-releases" (later licensees are often the current owner).
3. Companies House (UK) for the publisher's status; a dissolved company's unassigned copyrights pass to the Crown (Bona Vacantia Division, Government Legal Department).
4. Recent official re-releases (ZX Spectrum Next bundles, The Spectrum / ZX mini consoles, Rare Replay, Antstream, Evercade) — whoever licensed those is active.
5. Interviews (worldofspectrum.net/interviews, Retro Gamer) often say who kept the rights.

# word-bluff (working name)

An Icelandic "bluff the definition" party game for 4–10 players on their own phones: everyone sees a rare, real Icelandic word, writes a convincing fake definition, then votes for the real one. The game's name is chosen in Phase 2.

**Status: Phase 1 (feasibility) is done and waiting for the owner's GO.** No game code exists yet, and nothing here deploys: CI only builds folders under `games/` that have a `package.json`.

- [`research/REPORT.md`](research/REPORT.md): the Phase 1 report (word counts per difficulty level, samples, source terms, GO/NO-GO).
- [`research/words.json`](research/words.json): 1,800 verified words. Each has a definition in our own words, its source and link, a difficulty score 1–10, a child-friendly flag and a theme. The file also holds the proposed difficulty levels (score windows). Treat it as CC BY-SA 4.0, because most definitions are paraphrased from Íslensk nútímamálsorðabók (© Stofnun Árna Magnússonar, CC BY-SA 4.0 dataset of 2023).
- [`research/unverified-candidates.json`](research/unverified-candidates.json) and [`research/rejected-candidates.json`](research/rejected-candidates.json): words not used, with reasons.
- [`research/tools/`](research/tools/): the lookup through málið.is, the review rubric and the scripts that built the lists.

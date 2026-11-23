# word-bluff (working name)

An Icelandic "bluff the definition" party game for 4–10 players on their own phones: everyone sees a rare, real Icelandic word, writes a convincing fake definition, then votes for the real one. The game's name is chosen in Phase 2.

**Status: Phase 1 (feasibility) is done and waiting for the owner's GO.** No game code exists yet, and nothing here deploys: CI only builds folders under `games/` that have a `package.json`.

- [`research/REPORT.md`](research/REPORT.md): the Phase 1 report (word counts, samples, source terms, GO/NO-GO).
- [`research/verified-words.json`](research/verified-words.json): 391 verified words, each with a definition in our own words, its source and link, and an obscurity rating. Treat it as CC BY-SA 4.0, because some definitions are paraphrased from Íslensk nútímamálsorðabók (© Stofnun Árna Magnússonar, CC BY-SA 4.0 dataset of 2023).
- [`research/unverified-candidates.json`](research/unverified-candidates.json) and [`research/rejected-candidates.json`](research/rejected-candidates.json): words not used, with reasons.
- [`research/tools/`](research/tools/): the lookup through málið.is, the review rubric and the scripts that built the lists.

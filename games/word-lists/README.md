# Icelandic word lists for party games

Word lists in Icelandic for several original party games:
- a code-clue team game;
- a grid-clue game;
- an outsider (bluffing) game;
- a describe-around-traps game;
- a category race;
- a one-syllable describing game.

No game code lives here. This folder has no `package.json`, so CI neither builds nor deploys it.

## The data (`data/`)

All files are UTF-8 JSON. Field names are Icelandic.

| File | Holds | For |
|---|---|---|
| [`common-nouns.json`](data/common-nouns.json) | 1,534 well-known nouns. Each has: gender, how well known it is (`thekking` 1–4), whether it is concrete, its everyday meanings if it has several (`margraett`, `merkingar`), how many clue angles it gives (`litriki` 1–3), how hard it is to describe (`lysanleiki` 1–3), a child-friendly flag, a theme, its syllable count and whether it is a compound. `leikir` lists the games the word suits; the selection rules are at the top of the file. | code-clue, grid-clue, traps, one-syllable game |
| [`topic-grids.json`](data/topic-grids.json) | 118 topics with exactly 16 words each, plus difficulty and a child-friendly flag | outsider game |
| [`category-prompts.json`](data/category-prompts.json) | 316 short category prompts, each with 8 example answers for the judge, difficulty, child-friendly flag and type | category race |
| [`one-syllable-words.json`](data/one-syllable-words.json) | 1,908 common one-syllable word forms (with word class and lemma) | checking clues in the one-syllable game |
| [`rare-words.json`](data/rare-words.json) | 1,800 rare words with definitions and difficulty 1–10, from the abandoned bluff-the-definition game. No game uses it. | none |

`ostadfest` in the grids and prompts lists the few items (6 in all) that no source on málið.is confirms. They are mostly foreign landmark names.

**Licence:** treat the files as CC BY-SA 4.0. They are drawn from these datasets of the Árni Magnússon Institute (© Stofnun Árna Magnússonar í íslenskum fræðum):
- Íslensk nútímamálsorðabók (2023 dataset, CC BY-SA 4.0);
- the CEFR vocabulary lists for Icelandic (CC BY 4.0);
- the Icelandic Gigaword frequency lists (CC BY 4.0).

A game using them should credit the institute.

## The research (`research/`)

- [`research/REPORT.md`](research/REPORT.md): how the lists were built, the counts per game, samples and open questions.
- `research/rejected-nouns.json`: the 1,466 nouns that were reviewed and rejected, each with its reason.
- `research/tools/`: the review rules, the scripts that built the lists and the fixes applied by hand.
- `research/bluff/`: the reports and rejected lists from the bluff game, kept for the record.

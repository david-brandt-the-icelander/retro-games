# Word lists for six party games: report

Built 23 November 2026, after the bluff-the-definition game was dropped. These are original lists suited to each mechanic. No card text, topics or names from the published games inspiring them were used.

## Is there enough for each game?

Yes, with plenty to spare for every game.

| Game mechanic | List and filter | Words / items | What one game uses | Rough number of games without repeats |
|---|---|---|---|---|
| Code-clue team game (4 secret keywords per team) | `common-nouns.json`, `leikir` has `dulmal` | 1,145 (1,138 child-friendly) | 8 | ~140 |
| Grid-clue game (5 row + 5 column words) | `common-nouns.json`, `krossvisbendingar` | 1,014 | 10 | ~100 |
| Describe-around-traps game | `common-nouns.json`, `gildruord`; `lysanleiki` 1–3 sets difficulty | 1,534 | 20–30 | 50+ |
| One-syllable describing game, easy cards | `einsatkvaedis_lett` | 835 | about 15 | 55 |
| One-syllable describing game, harder cards | `einsatkvaedis_erfitt` | 1,052 | about 15 | 70 |
| Outsider game | `topic-grids.json` | 118 topics × 16 words | 1 topic per round | each topic replays with a different secret word |
| Category race | `category-prompts.json` | 316 prompts | a deck of about 60–80 | 4+ |
| Checking one-syllable clues | `one-syllable-words.json` | 1,908 forms | — | — |

## How the lists were built

### Common nouns (`common-nouns.json`)
- **Candidates:** 3,000 nouns drawn at random from the **CEFR vocabulary lists for Icelandic** (CLARIN-IS, CC BY 4.0): 650 from A1, 900 from A2, 850 from B1 and 600 from B2. These lists hold the vocabulary of learners, so every adult knows these words.
- **Evidence given to the reviewers:**
  - each word's sense definitions in the ÍNO 2023 dataset (CC BY-SA 4.0);
  - its count in the Icelandic Gigaword Corpus (CC BY 4.0).
- **Review:** six review agents judged every word against [`tools/RUBRIC_nouns.md`](tools/RUBRIC_nouns.md). I then audited samples and dropped or corrected borderline cases:
  - alcohol: *bjór*, *vín*, *hanastél*;
  - blood, accidents and grief: *blóð*, *slys*, *sorg*;
  - a word with a slang sense: *túr*;
  - wrong genders where ÍNO's first entry was a rarer homograph: *ár*, *heiði*, *skeið*, *egg*;
  - an illness sense: the *kóróna* meaning "the virus".
- **Result:** 1,534 kept and 1,466 rejected.

  | Reason for rejection | Words |
  |---|---|
  | abstract or administrative | 726 |
  | dull transparent compound | 380 |
  | unsuitable | 175 |
  | too obscure | 95 |
  | variant | 79 |
  | dropped in my audit | 11 |
- **Fields:**

  | Field | Means | Values in the list |
  |---|---|---|
  | `thekking` | how well known | 1 = a 7-year-old knows it (696); 2 = a 10–12-year-old does (522); 3 = every adult (306); 4 = most adults (10) |
  | `hlutbundid` | concrete | 1,331 words |
  | `margraett` | two or more everyday meanings | 228 words, e.g. *horn* (dýrahorn / hljóðfæri / horn í herbergi), *lest* (járnbrautarlest / lest í skipi), *tunga* (líkamshluti / tungumál / tunga á skó). Useful for the code-clue and grid-clue games. |
  | `litriki` | how many clue angles the word gives | 1–3 |
  | `lysanleiki` | how hard it is to describe | 1 easy … 3 hard |
  | `barnvaent` | child-friendly | 1,516 words |
  | `flokkur` | theme | — |
  | `atkvaedi` | syllable count | — |
  | `samsett` | compound (from ÍNO's compound split) | — |
  | `tengill` | ÍNO or málið.is link | — |

### Topic grids (`topic-grids.json`)
- **Writing:** two agents each wrote 60 original topics of exactly 16 words against [`tools/BRIEF_categories.md`](tools/BRIEF_categories.md). They split the themes to avoid overlap:
  - Icelandic nature, animals, food, sea, farming, places, folklore and myth;
  - home, school, jobs, sports, music, transport, technology, world geography, fiction and culture.
- **Checking:** every word was looked up in the corpus lemma list, ÍNO and the CEFR lists, and anything not found was checked on málið.is, including inflected forms (for example *piparkökur* → *piparkaka*).
- **Fixes by hand:**
  - two cookie names that no source knows (*kókostoppar*, *marengstoppar*) were replaced with verified ones;
  - *hrútspungar* was replaced in two grids that might be read as crude or that are child-friendly;
  - *dögg* came out of "Úrkoma";
  - *Kólosseum*, an uncertain spelling, became *Kreml*;
  - two topics duplicating others were dropped.
- **Result:** 118 topics, 80 of them child-friendly.
- **Unconfirmed:** *Golden Gate-brúin* and *Sfinxinn* in "Fræg kennileiti" are well-known foreign names that the Icelandic sources don't list.

### Category prompts (`category-prompts.json`)
- **Writing:** two agents wrote 160 prompts each, split by type.
- **Types:**

  | Type | Prompts |
  |---|---|
  | hlutir | 40 |
  | dýr_og_jurtir | 40 |
  | matur | 40 |
  | staðir | 40 |
  | fólk_og_störf | 32 |
  | orðaleikir | 32 |
  | annað | 32 |
  | menning | 31 |
  | íslenskt | 29 |
- **Prompt styles:** plain categories ("Fiskur"), properties ("Eitthvað kalt"), places ("Eitthvað í réttunum") and word play ("Orð sem byrjar á 'hv'").
- **Checking:** each prompt has 8 checked example answers for the judge.
- **Dropped:** four prompts that would cause disputes or touch trademarks ("Íslenskt nýyrði", "Íslenskur jólasveinn" with only 13 answers, "Myndasögupersóna", "Íslenskt ættarnafn").
- **Result:** 316 prompts, 272 of them child-friendly.
- **Unconfirmed examples:** *rúðusköfa*, *Bastilludagurinn*, *Miðgarðsormurinn* and *gera snjóengil*.

### One-syllable word forms (`one-syllable-words.json`)
- **Source:** every word form in the CEFR lists (A1–B2).
- **Rule:** a form is kept if it has one syllable, counted by vowel nuclei, with *au*, *ei* and *ey* counted as one (`tools/syllables.py`, with tests).
- **Result:** 1,908 forms; 974 of them are noun forms. It covers inflected forms too, so *hest* and *hönd* are in while *hestur* is not.
- **Ordering:** sorted by how common the lemma is.
- **Use:** a game can use the list to check a clue automatically, or to show players a word bank.

## Samples

**Nouns:** pollabuxur, froskur, logn, veiðistöng, draumur, vörubíll, úlfur, lystigarður, geit, partí, nagladekk, geisli, hnetusmjör, feldur, stoppistöð, vinur, þvottahús, eplabaka, kalkúnn, örbylgjuofn, himinn, dúkka.

**Words with several meanings:**
- *sæti*: stóll / sæti í keppni
- *grind*: rammi / hlið
- *bolur*: stuttermabolur / búkur / trjábolur
- *stafur*: bókstafur / göngustafur
- *alda*: sjávarbylgja / hrina
- *bragð*: bragð af mat / brella
- *lið*: íþróttalið / liðamót
- *réttur*: matarréttur / réttindi / dómstóll

**Topic grids:**
- "Á byggingarsvæði": krani, grafa, steypubíll, vinnupallur, hjálmur …
- "Jólamatur": hangikjöt, rjúpa, hamborgarhryggur, möndlugrautur, uppstúfur, skata …
- "Persónueinkenni": feiminn, hress, forvitinn, montinn, stríðinn, gleyminn …
- "Á höfuðborgarsvæðinu": Reykjavík, Kópavogur, Breiðholt, Grafarvogur, Fossvogur …

**Category prompts:**
- "Eitthvað grænt"
- "Sjófugl"
- "Dýr með horn"
- "Orð sem endar á '-bolti'"
- "Eitthvað kalt"
- "Eitthvað í réttunum"
- "Eitthvað með fjórum fótum"
- "Merkisdagur á Íslandi"
- "Samsett orð með 'fjall'"

## Open points for a native speaker
- **Holiday names:** *þorláksmessa* and *jónsmessa* are written with a lower-case first letter in one grid, following the spelling rules, and capitalised in another prompt. Choose one style.
- **Spellings:** check *kandíflos* (BÍN has it; *kandífloss* is also used), *pítsa* (used throughout instead of *pizza*) and *dammtafl* (people may say *damm*).
- **Hard grids:** "Íslensk blóm" and "Eyjar við Ísland" include specialist items such as *holurt*, *Kolbeinsey* and *Bjarnarey*. They are marked hard.
- **Scores:** `thekking`, `litriki` and `lysanleiki` are the reviewers' estimates. A native speaker may want to move some; each is one number.

## Sources and terms
| Source | What we used | Licence |
|---|---|---|
| CEFR vocabulary lists for Icelandic (http://hdl.handle.net/20.500.12537/391) | Candidate nouns and the word forms for the one-syllable list | CC BY 4.0 |
| Íslensk nútímamálsorðabók, 2023 dataset (http://hdl.handle.net/20.500.12537/318) | Senses (evidence for meanings), gender, compound split, links | CC BY-SA 4.0 |
| Frequency lists for Icelandic 23.06 (http://hdl.handle.net/20.500.12537/314) | Familiarity signal and existence check | CC BY 4.0 |
| Málið.is | Existence check for words not in the lists above, including inflected forms | No terms published; its robots.txt allows crawling. About 140 lookups (109 by the build script plus about 30 by hand). |

Credit: "Stofnun Árna Magnússonar í íslenskum fræðum: Íslensk nútímamálsorðabók; orðaforðalistar Evrópska tungumálarammans fyrir íslensku; tíðnilistar Risamálheildarinnar."

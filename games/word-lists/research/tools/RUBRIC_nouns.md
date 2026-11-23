# Review rubric v3: common Icelandic nouns for clue-giving and describing games

The list feeds several original party games played by native Icelandic speakers (adults, sometimes with children):
- **Code-clue team game**: each team has 4 secret keywords and gives one-word clues pointing at them, across many rounds,
  while the other team listens and tries to crack the code. Keywords need rich, varied associations.
- **Grid-clue game**: a 5×5 grid with a word on each row and column; a player gives one clue that links a row word and a
  column word. Words must be concrete or vivid and combine well with many others.
- **Describe-around-traps game**: a player describes a target word while opponents have secretly banned some words.
- **One-syllable describing game**: a player describes a target using only one-syllable words.
All players must KNOW the words — obscure words are useless here (the opposite of a bluffing game).

## Input
A JSONL file, one noun per line: the lemma, its CEFR learner level (A1 easiest … B2), its count in the Icelandic
Gigaword Corpus ("tíðni"), gender, ÍNO compound split ("samsett", e.g. "kvikmynda-stjarna"), ÍNO's sense definitions
(up to 4, truncated) and the number of ÍNO senses, and links. All words exist (they are in the CEFR learner lists).

## Decide keep or reject for EVERY word
Reject with "astaeda":
- ABSTRACT — an abstract, administrative, academic or technical noun that is hard to clue or describe and sparks no
  images (e.g. "fyrirkomulag", "aðild", "forsenda", "rekstrarkostnaður"). Common abstract words that are vivid and
  easy to talk about (e.g. "draumur", "ást", "hræðsla", "frí") may be KEPT.
- UNSUITABLE — sexual, crude, medical/illness/disease, death, violence/weapons-of-war, drugs, politics, religion-heavy,
  brands/proper names, insults or labels for groups of people.
- TOO_OBSCURE — a sizeable share of adult native speakers would not know it.
- VARIANT — a spelling variant, inflected form, plural of another noun, or a near-duplicate that adds nothing
  (e.g. diminutive forms of a word you'd keep anyway).
- DULL_COMPOUND — a long transparent compound that is only its parts (e.g. "bílastæðagjald", "starfsmannafundur").
  Short, familiar compounds that are one idea (e.g. "jólasveinn", "eldgos", "regnbogi", "ísskápur") are GOOD.

## For kept words output
- "kyn": "kk." "kvk." "hk." (from input; add " ft." if plural-only).
- "thekking": 1–4 — how universally known: 1 = every 7-year-old knows it; 2 = every 10–12-year-old; 3 = every adult,
  some children not; 4 = most adults, not all.
- "hlutbundid": true if it is something you can see, touch, hear or picture (animal, object, place, person-role, food,
  weather, event like "afmæli"); false if abstract.
- "margraett": true if the word has two or more DIFFERENT meanings that ordinary people know (e.g. "lest" train / ship's
  hold, "kúla" ball / bullet / bump, "mús" animal / computer mouse, "stjarna" star / celebrity). Use the ÍNO senses as
  evidence, but count only meanings people actually know. "merkingar": list those meanings briefly (Icelandic, 1–4 words
  each), e.g. ["dýr", "tölvumús"]. Empty list if not margraett.
- "litriki": 1–3 — how many associations and clue angles the word gives: 3 = very rich (e.g. "eldfjall", "jól",
  "hafið", "konungur"); 2 = good; 1 = narrow (one obvious association).
- "lysanleiki": 1–3 — how hard it is to DESCRIBE without saying it: 1 = easy (e.g. "hundur", "pizza"); 2 = medium
  (e.g. "bókasafn", "tunglmyrkvi"); 3 = hard (e.g. "tækifæri", "kurteisi").
- "barnvaent": true if fine and meaningful for children of 8–12.
- "flokkur": one theme tag: dýr, matur, heimili, fatnaður, náttúra, veður, líkami (only non-medical parts like hönd,
  nef), fólk, störf, íþróttir, tónlist, farartæki, tækni, skóli, borg, sjór, sveit, tími, hátíðir, leikir, list,
  vísindi, ævintýri, tilfinningar, annað.
- "athugasemd": optional short note.

Rejected: {"w":..., "keep": false, "astaeda": "..."}.

## Output
Write a JSON array (one object per input line, in input order, every word present, "keep": true/false) to the output
path given in your task, with Python json.dump(..., ensure_ascii=False, indent=0). Judge every word yourself; a script
may only assemble and save what you wrote and copy links from the input. No network access; do not edit other files.
Report only: kept count, rejected by reason, counts of thekking 1–4, how many margraett, how many hlutbundid,
how many barnvaent, and up to 5 words you are unsure about.

# Review rubric v2: Icelandic "bluff the definition" word list with difficulty levels

The game: players see a real Icelandic word, each writes a convincing fake definition, then everyone votes for the
real one. Players are native Icelandic speakers. The game has difficulty levels; the easiest must be playable by a
family with children (about 10–12 years old), the hardest by educated adults aged 40–60 who love obscure words.

Every kept word gets a DIFFICULTY score 1–10 = how few people would know its meaning. A level is a window on this
scale (e.g. children 1–4, hardest 6–10), so every score from 1 to 10 is useful.

## Input
A JSONL file. Each line is one word with evidence fetched from the Árni Magnússon Institute's dictionaries:
ÍNO (Íslensk nútímamálsorðabók, Icelandic definitions, usage/subject labels in brackets e.g. [gamalt], [þjóðtrú]),
sometimes Blöndal (Icelandic–Danish dictionary 1920–24, Danish glosses), Ritmálssafn (citation counts), ISLEX
(translations), Íðorðabanki, Orðsifjabók (etymological dictionary), and "tíðni_risamálheild" = how many times the
word (lemma) occurs in the 2-billion-word Icelandic Gigaword Corpus (a rough familiarity signal: <50 very rare,
~500 uncommon, >10,000 common — but homographs inflate it, e.g. a rare sense of a common word).

## Decide keep or reject for EVERY word

Reject with "astaeda":
- TOO_EASY — a typical Icelandic 10–12-year-old already knows the meaning (everyday words). Useless at any level.
- TRANSPARENT — the meaning is easy to work out from the word's parts (e.g. "sauðskinnsskór", "fiskbúð", "kvöldmatur").
  Mildly misleading compounds are good; keep those.
- UNSUITABLE — crude, sexual, scatological, offensive, medical/illness/disease/body functions, death/corpses, violence or
  cruelty, insults aimed at people or groups, politics/brands/proper names.
- NO_CLEAR_MEANING — the evidence does not clearly state a meaning (only a cross-reference, only an example, empty).
- BORING — technical jargon, abstract bureaucratic/legal/academic words, or pure species names whose only possible
  definition is "a kind of X" with nothing interesting (players can't enjoy the reveal). Use sparingly.
- DUPLICATE — near-identical to another word in the same file that you kept (spelling variant, plural of it).

Domain words ARE fair game: a word that people inside a trade or field know (farmers, sailors, fishermen, weavers,
clergy, horse people, cooks of old food) but most people outside it don't is GOOD — score it by how many people in the
general adult population know it.

## For kept words, write

- "ordflokkur": "kk." "kvk." "hk." "so." "lo." "ao." (add " ft." for plural-only nouns).
- "skilgreining": ONE short, plain, natural Icelandic sentence (max ~14 words), in YOUR OWN WORDS — paraphrase, do not
  copy the dictionary wording; translate Danish glosses. Base the meaning ONLY on the evidence; never add meaning from
  memory. Dictionary-gloss style, e.g. "Lykkja úr horni eða tré sem reipi er dregið í gegnum við heybindingu."
  If "barnvaent" is true, a 10-year-old must understand the sentence (simple words).
  Correct spelling with þ, ð, æ, ö and accents. If several senses: choose ONE clearly supported, fun sense.
- "heimild": "ÍNO", "Blöndal", "ISLEX", "Íðorðabanki" or "Orðsifjabók" — the source that supports your definition.
- "tengill": that source's link from "links" (Íðorðabanki and Orðsifjabók use the Málið link).
- "malid": the Málið link.
- "studningur": a SHORT verbatim fragment (≤15 words) of the evidence supporting the definition (audit only).
- "erfidleiki": integer 1–10, using these anchors (the meaning of the word as you defined it):
   1  Nearly all adults know it well; many children do not.        e.g. skafrenningur, skreið, smali
   2  Almost all adults know it.                                    e.g. hjallur, naust, kafald
   3  Most adults know it.                                          e.g. fráfærur, landpóstur
   4  Many adults know it, some only vaguely.                       e.g. tilberi, hrævareldur
   5  About half of adults know it; well known inside a domain.     e.g. geldfé, fjallkóngur, nónbil
   6  Fewer than half know it; domain word or old word.             e.g. landfesti, kaskeiti, skari (snjóskel)
   7  Most adults do not know it.                                   e.g. hagldir, kljásteinn, stokkabelti
   8  Very few adults know it.                                      e.g. golsóttur, ljóri, eykt
   9  Almost nobody knows it, even word lovers.                     e.g. hræll, garðaband, fantur (= kaffikrús)
   10 Practically unknown; only in old dictionaries.                e.g. grjúpán, frolla, rjúpa (= hnykill)
- "barnvaent": true if both the word and the definition are fine and understandable for a child of 10–12
  (nothing scary-gory, adult, alcohol/tobacco, religion-heavy or cruel; the concept is something a child can picture).
- "sjaldgaef_merking": true if the definition is a rare sense of a word whose COMMON meaning most people know
  (e.g. "rjúpa" = hnykill, "áróður" = róður á móti straumi). Such words are fun for adults but confusing for children.
- "flokkur": one short theme tag in Icelandic: veður, sjór, sauðfé, búskapur, hestar, þjóðtrú, matur, fatnaður,
  hús, verkfæri, handverk, dýr, jurtir, fólk, tími, mælieiningar, kirkja, saga, skáldamál, bragfræði, landslag,
  athöfn, eiginleiki, annað.
- "ovisst_mal": true if you are unsure your Icelandic sentence is correct and natural.
- "athugasemd": optional short note (sense chosen, regional label, etc.).

Rejected: {"w":..., "keep": false, "astaeda": "...", "athugasemd": optional}.

## Re-scoring task (only when the task says "rescore")
Input lines already have a checked definition. Keep the definition as it is (unless it is clearly wrong; then set
"athugasemd" saying why). Output for each: {"w", "keep": true, "erfidleiki", "barnvaent", "sjaldgaef_merking",
"flokkur", "athugasemd"} — or "keep": false with "astaeda" only if it is clearly UNSUITABLE.

## Output
Write a JSON array (one object per input line, input order, every word present) to the output path given in your task,
with Python json.dump(..., ensure_ascii=False, indent=1). Judge every word yourself; a script may only assemble and
save what you wrote and fill links in from the input. Do not access the network. Do not edit other files.
Report only: kept count, rejected count by reason, the distribution of erfidleiki among kept words (count per score),
how many are barnvaent, and up to 5 words you are unsure about.

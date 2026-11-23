# Review rubric: Icelandic "bluff the definition" word list

You are reviewing candidate words for a party game played by educated native Icelandic speakers aged 40–60.
Players see a rare real Icelandic word, write fake definitions, then vote for the real one.

Input: a JSONL file. Each line is one candidate word with the dictionary evidence that was fetched from málið.is
(Árni Magnússon Institute): ÍNO (Íslensk nútímamálsorðabók, Icelandic definitions, labels such as "gamalt"),
Blöndal (Icelandic–Danish dictionary 1920–24, Danish glosses; regional labels in parentheses, e.g. "(Austf.)"),
Ritmálssafn (number and age of written citations — few/old citations suggest obscurity), ISLEX (English/Danish
translations), Íðorðabanki (term bank), Orðsifjabók (etymological dictionary), and links.

For EVERY word decide keep or reject.

KEEP only if ALL hold:
1. REAL + MEANING VERIFIED: the evidence lines given clearly state the meaning. Base the definition ONLY on that evidence.
   Never add meaning from your own memory. If the evidence is ambiguous, too thin, or only an example sentence → reject NO_CLEAR_MEANING.
2. OBSCURE: an educated native speaker aged 40–60 would probably NOT know it (or only very vaguely). Everyday words,
   well-known birds/fish/plants, well-known food, school-taught terms (e.g. common month names Þorri/Góa), words in
   common modern use → reject KNOWN. Be strict: if you think most such people know it, reject.
3. NOT GIVEN AWAY: the meaning must not be easy to work out from its parts. Transparent compounds
   (e.g. "sauðskinnsskór" = shoes of sheepskin) → reject TRANSPARENT. Misleading compounds or words that look like a
   common word but mean something else are ideal (pick the obscure sense then).
4. SHORT: the meaning fits one short plain Icelandic sentence.
5. SUITABLE: not offensive, crude, sexual, scatological, medical, or about illness, death/corpses, or work-related
   hardship that could upset → reject UNSUITABLE. Insults/slurs aimed at people → UNSUITABLE.
If a word has several senses, choose ONE sense that is clearly supported, obscure and fun; say which.

For kept words write:
- "ordflokkur": one of "kk." "kvk." "hk." "so." "lo." "ao." (add " ft." for plural-only nouns, e.g. "kvk. ft.").
- "skilgreining": ONE short, natural, plain Icelandic sentence (max ~14 words), in YOUR OWN WORDS — do not copy
  the ÍNO/ISLEX/Blöndal wording verbatim; paraphrase (translate Danish glosses into natural Icelandic).
  Style like a dictionary gloss, no trailing explanation, e.g. "Lykkja úr horni eða tré sem reipi er dregið í gegnum við heybindingu."
  Must use correct Icelandic spelling incl. þ, ð, æ, ö and accents.
- "heimild": the name of the source whose text supports the definition best: "ÍNO", "Blöndal", "ISLEX", "Íðorðabanki", "Orðsifjabók" (Orðsifjabók link = the Málið link). "ÍNO_merkt_skýring" lines are ÍNO definitions with ÍNO usage labels in brackets (e.g. gamalt, skáldamál, þjóðtrú) — they count as ÍNO evidence.
- "tengill": that source's link from the "links" field (fall back to the Málið link).
- "malid": the Málið link.
- "studningur": a SHORT verbatim fragment (≤ 15 words) of the evidence that supports the definition (for audit only).
- "obscurity": 1, 2 or 3. 3 = almost no one in the target group knows it; 2 = most would not know it;
  1 = a fair number may half-know it, but it is still good for bluffing.
- "ovisst_mal": true if you are not confident your Icelandic sentence is correct, natural Icelandic; else false.
- "athugasemd": optional short note (e.g. regional label, sense chosen).

For rejected words: {"w":..., "keep": false, "astaeda": "KNOWN|TRANSPARENT|NO_CLEAR_MEANING|UNSUITABLE|DUPLICATE", "athugasemd": optional}.

Output: write a JSON array (one object per input line, in input order, every input word present) to the output path
given in your task, using Python's json.dump(..., ensure_ascii=False, indent=1). Kept objects have "keep": true.
Then report only: number kept, number rejected by reason, and up to 5 words whose meaning or wording you are unsure about.
Do not edit any other files. Do not access the network.

# Phase 1 report: is there a big enough word list?

Research for an Icelandic "bluff the definition" party game (working folder name `word-bluff`; the game's name is chosen in Phase 2). Date of the lookups: 23 November 2026.

## Verdict: GO

**391 verified, usable words.** The target was at least 200, ideally 300+. Even keeping only the two harder obscurity levels (2 and 3) leaves 280 words.

## What "verified" means here

- Every word on the list was looked up in the Árni Magnússon Institute's databases through **málið.is**, which returns, for one word, its entries in:
  - ÍNO (Íslensk nútímamálsorðabók)
  - Blöndal's Icelandic–Danish dictionary
  - Ritmálssafn, with its citation count and age
  - ISLEX
  - Íðorðabanki
  - Íslensk orðsifjabók
  - BÍN
- A word counts only if one of those entries **states its meaning**. The definition was written from that entry text only, never from memory. It was paraphrased into one plain Icelandic sentence, and Blöndal's Danish glosses were translated.
- Every word in `verified-words.json` records:
  - its word class;
  - our definition;
  - the source and a direct link (ÍNO `…/ord/<id>`, Blöndal `…/faersla/<id>`, or the málið.is page);
  - a short verbatim fragment of the source that supports the definition (for checking, not for the game);
  - an obscurity rating from 1 to 3.

## How the list was built

| Step | Words |
|---|---|
| Candidates looked up (the two lists below overlap by 33) | 1,970 |
| From my own lists (weather, sheep farming, sea, folklore, old trades, household, time-keeping, church, verse forms and more) | 1,148 |
| From the ÍNO 2023 open dataset (CC BY-SA 4.0): senses ÍNO itself labels *gamalt, gamaldags, fornt, skáldamál, sjaldgæft, í eldra máli, staðbundið, úrelt*, or subject *þjóðtrú, veðurfræði, bragfræði, goðafræði, sögulegt* | 855 |
| Not found in any source at all | 32 |
| Found, but no source gives a usable meaning | 116 |
| Reviewed against the five criteria | 1,854 |
| Rejected: KNOWN (an educated 40–60-year-old would know it) | 1,050 |
| Rejected: TRANSPARENT (meaning obvious from the parts) | 289 |
| Rejected: UNSUITABLE (crude, sexual, medical, illness, death, insults aimed at people) | 75 |
| Rejected: NO_CLEAR_MEANING (source too thin) | 20 |
| Rejected: duplicates or near-duplicates | 12 |
| Dropped in my final audit (thin support, contradictory senses, too close to medical) | 17 |
| **Verified and usable** | **391** |

The 1,463 rejected words, each with its reason, are in `rejected-candidates.json`.

### Verified words by source (the source the definition rests on)

| Source | Words |
|---|---|
| Íslensk nútímamálsorðabók (ÍNO) | 230 |
| Blöndal, Íslensk-dönsk orðabók (1920–24) | 122 |
| Íslensk orðsifjabók (Ásgeir Blöndal Magnússon) | 26 |
| Íðorðabankinn | 11 |
| ISLEX | 2 |
| **Total** | **391** |

Most words are also attested in other collections; the full evidence is behind each word's málið.is link.

### Verified words by obscurity

| Rating | Meaning | Words |
|---|---|---|
| 3 | Almost nobody in the group will know it | 68 |
| 2 | Most will not know it | 212 |
| 1 | Some may half-know it; still fine for bluffing | 111 |

The obscurity ratings and the KNOWN and TRANSPARENT judgments are my estimates, not a native speaker's. The sample below is there so you can calibrate them.

## Unverified candidates (kept separately, not used)

There are **136** of them, in `unverified-candidates.json`:
- 32 words were not found in any source;
- 84 were found only in BÍN, Ritmálssafn or the spelling dictionary, which list the word but give no meaning;
- 20 had evidence too thin to state a meaning safely (for example, only a cross-reference).

None of these will be used unless a source is found for them.

## 20 random sample words

These were drawn at random (fixed seed) from the verified list.

| Word | Class | Definition | Source | Obscurity |
|---|---|---|---|---|
| þingmannaleið | kvk. | Forn mælikvarði á dagleið ferðamanns, um 37,5 kílómetrar. | [Íðorðabanki via málið](https://malid.is/leit/%C3%BEingmannalei%C3%B0) | 1 |
| skafl | kk. | Broddur á skeifu sem kemur í veg fyrir að hestur renni á ís. | [Blöndal](https://blondal.arnastofnun.is/faersla/247711) | 1 |
| stokkabelti | hk. | Belti sett saman úr ferhyrndum málmplötum, oftast úr silfri. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/39578) | 1 |
| málnyta | kvk. | Öll mjólkin sem fæst úr einum mjöltum á bænum. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/59952) | 2 |
| frolla | kvk. | Húfa sem þykir ljót og ósmekkleg. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/13708) | 3 |
| gassi | kk. | Karlfugl gæsar. | [Blöndal](https://blondal.arnastofnun.is/faersla/229249) | 2 |
| samur | kk. | Hafið eða sjórinn, í fornum þulum. | [Orðsifjabók via málið](https://malid.is/leit/samur) | 3 |
| denging | kvk. | Það að þynna og skerpa egg á ljá. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/8089) | 2 |
| rjól | hk. | Tóbaksblöð undin saman í langan streng. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/33529) | 1 |
| kollekta | kvk. | Bæn sem prestur flytur fyrir altari á undan guðspjalli dagsins. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/24368) | 2 |
| krúkk | lo. | Alveg peningalaus, blankur. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/24769) | 2 |
| ífæra | kvk. | Stór krókur til að krækja í stóran fisk og draga hann um borð. | [Blöndal](https://blondal.arnastofnun.is/faersla/235304) | 1 |
| glýja | kvk. | Stuttur og ótraustur þurrkur, dauft þerriveður. | [Blöndal](https://blondal.arnastofnun.is/faersla/230011) | 2 |
| barki | kk. | Fremsti hluti báts eða skips, framstafninn. | [Blöndal](https://blondal.arnastofnun.is/faersla/221973) | 2 |
| byrðingur | kk. | Stór bátur sem notaður var til vöruflutninga. | [Blöndal](https://blondal.arnastofnun.is/faersla/222564) | 2 |
| dvergur | kk. | Stutt lóðrétt stoð í þakgrind torfbæjar sem styður mænisásinn. | [Íðorðabanki via málið](https://malid.is/leit/dvergur) | 2 |
| leiðarþing | hk. | Þing sem haldið var í héraði að loknu Alþingi til að segja frá störfum þess. | [Íðorðabanki via málið](https://malid.is/leit/lei%C3%B0ar%C3%BEing) | 2 |
| stjóri | kk. | Steinn sem notaður er sem akkeri fyrir litla báta. | [Blöndal](https://blondal.arnastofnun.is/faersla/251785) | 2 |
| hraunkarl | kk. | Hár og oddhvass klettur sem rís upp úr hrauni. | [Blöndal](https://blondal.arnastofnun.is/faersla/233906) | 2 |
| árefti | hk. | Borð eða hellur sem lagðar eru á rafta undir torfinu í torfþaki. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/4301) | 2 |

### One kind of word you should judge

A large share of the words (the reviewers' notes flag up to about 130, roughly a third) are a **rare sense of a word everyone knows**, or have a common meaning alongside the obscure one. Examples:
- *rjúpa*: hnykill af garni;
- *almenningur*: stærsta hólfið í skilarétt;
- *áróður*: róður á móti straumi;
- *hnísa*: fremsti hluti kjalar;
- *fantur*: stór kaffikrús úr leir;
- *fiðla*: slitin skeifa.

These make good bluffs. The risk is that a player writes the common meaning, believes it is "correct", and feels cheated. Options for Phase 2:
- show the word class and a hint such as "sjaldgæf merking";
- let you, as host, filter these out.

They are marked in each word's `athugasemd` field when the reviewer noted it.

## Terms of use of the sources

No dictionary website has a terms-of-use page, and arnastofnun.is has no general terms page, only a privacy policy. What is published:

| Source | What we used | Published terms | Attribution |
|---|---|---|---|
| ÍNO | Definitions (paraphrased) and links. The 2023 open dataset was used only to find candidate words. | CLARIN-IS dataset 2023-12: **CC BY-SA 4.0** (the licence header in the file itself). The February 2026 release changed to **CC BY-NC-ND 4.0**; we did not use that release's content. | "Íslensk nútímamálsorðabók. Halldóra Jónsdóttir og Þórdís Úlfarsdóttir (ritstj.). Reykjavík: Stofnun Árna Magnússonar í íslenskum fræðum." + link |
| Blöndal | Danish glosses translated and paraphrased, and links | No licence published. The site says the digital edition "er nú öllum opin og aðgengileg án endurgjalds". The 1920–24 text may be out of copyright (Sigfús Blöndal d. 1950); the 1963 supplement is not. | No format published. We cite "Íslensk-dönsk orðabók (Sigfús Blöndal), Stofnun Árna Magnússonar" + link. |
| ISLEX | Translations as evidence (2 definitions rest on it) | CLARIN-IS 2026: CC BY-SA 4.0 | "ISLEX. Þórdís Úlfarsdóttir (aðalritstj.). Reykjavík: Stofnun Árna Magnússonar í íslenskum fræðum." |
| Ritmálssafn | Citation counts, as a signal of obscurity only | None published | "Ritmálssafn Orðabókar Háskólans. Stofnun Árna Magnússonar í íslenskum fræðum." |
| Íslensk orðsifjabók, Íðorðabankinn | Glosses (paraphrased), shown on málið.is | Not checked separately; I found no terms on málið.is | Name the work and link to málið.is |
| Málið.is | All lookups | No terms published. Its robots.txt allows all. | — |
| BÍN | Not used for game content | Data CC BY-SA 4.0; copying the website is forbidden | Only needed if we show inflections |

**Can we use the list in a private game?** Yes, as far as anything published says. The list holds:
- headwords, which are facts;
- our own one-sentence paraphrases;
- links back to the sources.

It copies no dictionary entries.

**Recommendations:**
1. Treat the word-list file as **CC BY-SA 4.0**, because some definitions are paraphrased from ÍNO's BY-SA data.
2. Show a short credits line in the game naming Stofnun Árna Magnússonar and the dictionaries.
3. Keep the source link shown at each reveal.

**How the sites were queried:** all bulk lookups (about 2,000 requests, three at a time) went through malid.is, whose robots.txt allows crawling. While finding the API at the start, I also sent about ten manual requests straight to the Blöndal and ÍNO sites. Their robots.txt disallows bots other than the big search engines, so nothing further was sent there. No site publishes a rate limit.

## Wording I'm not fully confident about

A native speaker should check these definitions. The reason for doubt is in brackets.

- spesía: Gömul silfurmynt, ríkisdalur sem jafngilti fjórum krónum. (my reading of Blöndal's "Speciesdaler")
- strekkingur: Kapp við að komast áfram eða ná á tiltekinn stað. (Blöndal sense 1; most people know the wind sense)
- völur: Ávöl brún sem myndast á egg bitjárns þegar hún hefur lagst. (technical wording)
- þurs: Lítill skýhnoðri á himni. (rests on one Orðsifjabók gloss "skýflóki")
- hjáseta: Það starf að gæta mjólkurfjár í haga að sumarlagi. ("mjólkurfé" stands in for "kvíaær")
- jarðarhundrað: Gömul eining fyrir verðmæti jarðeignar, upphaflega metin í silfri og síðar í vaðmáli. (loose and long)
- kæfa: Þétt snjófok. (regional Blöndal sense, Árnessýsla)
- kaggi: Gamaldags hár hattur, þó heldur lægri en þeir algengustu. (ambiguous Danish)
- sili: Sá hluti reipis milli hagldanna sem byrðin hangir á. (technical)
- gullvöndur: Jurtategund af ætt maríuvanda. (thin; "maríuvandaætt" is my rendering of the gentian family)
- stakhenda: Enskur bragarháttur án ríms, fimm öfugir tvíliðir í hverri línu. ("öfugir tvíliðir" for iambs)
- flaga: Að gabba einhvern eða valda honum vonbrigðum. (one Blöndal gloss)
- basla: Að vera piparsveinn, lifa ókvæntur. (one Blöndal gloss; everyone knows the "strit" sense)

A further 8 definitions rest on a single short gloss in Orðsifjabók: dalur, gola, eta, brestur, malda, goggur, hafur, drós. They are faithful to it, but a second source would be nice.

Several sets are close in meaning and should not appear in the same game:
- sheep colours: golsóttur, botnóttur, arnhöfðóttur, bíldóttur, kápóttur, krúnóttur;
- the dolphins stökkull, hnýðingur and léttir;
- the sun dogs gíll and úlfur;
- the old time-of-day words ótta, eykt, miðmorgunn and miðmundi.

Phase 2 can tag the words by group and avoid repeats within a game.

## Files

- `verified-words.json`: the 391 usable words with definitions, sources, links, support fragments and ratings.
- `unverified-candidates.json`: the 136 words not used, each with its reason.
- `rejected-candidates.json`: the 1,463 reviewed words that were rejected, each with its reason.
- `tools/`: how to repeat the lookup:
  - `fetch.sh`: the málið.is lookup;
  - `summarise.py`: extracts the evidence;
  - `RUBRIC.md`: the review rules;
  - `consolidate.py`: builds the lists;
  - the two candidate lists.

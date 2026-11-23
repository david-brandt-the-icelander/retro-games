> **Archived.** The bluff-the-definition game was dropped on 23 November 2026, because an Icelandic edition of such a game already exists. Its word list is kept, unused, in `../../data/rare-words.json`, and the files named below now live in this folder or in `../../data/`.

# Phase 1 report: word list with difficulty levels

Research for an Icelandic "bluff the definition" party game (working folder name `word-bluff`; the game's name is chosen in Phase 2). Lookups made on 23 November 2026.

## Verdict: GO

`words.json` holds **1,800 verified words**. Each has:
- a difficulty score from 1 to 10;
- a child-friendly flag (`barnvaent`);
- a flag (`sjaldgaef_merking`) for a rare sense of a common word;
- a theme tag;
- a definition in our own words;
- its source and link.

Every difficulty level has far more than the 200 words that 20 games of 10 rounds need.

| Level (proposal) | Score window | Extra rule | Words |
|---|---|---|---|
| Barnvænt | 1–4 | child-friendly and not a rare sense of a common word | **973** |
| Létt | 2–6 | | **1,408** |
| Miðlungs | 4–8 | | **966** |
| Erfitt | 6–10 | | **537** |

The windows overlap, as on a bell curve. They are stored as data in `words.json` → `erfidleikastig`, so they can be moved without touching the word list. Within a window, the game can also favour words near the window's centre.

### What the difficulty score means

The score is how few people would know the meaning (of the sense defined). Each step has anchor words that all reviewers scored against.

| Score | Who knows it | Anchor examples |
|---|---|---|
| 1 | nearly all adults; many children don't | skafrenningur, skreið |
| 2 | almost all adults | hjallur, naust, kafald |
| 3 | most adults | fráfærur, landpóstur |
| 4 | many adults, some vaguely | tilberi, hrævareldur |
| 5 | about half of adults; well known inside a trade | geldfé, fjallkóngur |
| 6 | fewer than half; a trade or old word | landfesti, kaskeiti |
| 7 | most adults don't | hagldir, kljásteinn |
| 8 | very few adults | golsóttur, ljóri, eykt |
| 9 | almost nobody, even word lovers | hræll, garðaband |
| 10 | practically unknown | grjúpán, frolla, rjúpa (= hnykill) |

Words a typical 10–12-year-old already knows were rejected (TOO_EASY). Words known inside a trade (farmers, sailors, weavers, clergy) are fair game, as you asked; they are scored by how many people outside the trade know them.

**Distribution** (words per score, 1→10): 46 · 283 · 404 · 326 · 204 · 191 · 157 · 88 · 56 · 45. Most words sit in the middle and thin out towards both ends.

**Other counts:**
- 1,550 words are child-friendly;
- 181 are a rare sense of a common word (*rjúpa* = hnykill, *búr* = matargeymsla);
- the most common themes are: athöfn 238, eiginleiki 167, veður 104, fólk 104, dýr 101, sjór 97, matur 77, jurtir 69, hús 66, landslag 65, búskapur 63, handverk 62.

### Five random words per level

| Level | Examples |
|---|---|
| Barnvænt | vikapiltur (2): Strákur sem fer í sendiferðir og sinnir smáverkum fyrir aðra. · þeysa (2): Fara mjög hratt, til dæmis á hesti eða bíl. · vari (3): Viðvörun eða áminning. · nýlenduvara (4): Innflutt matvara, til dæmis ávextir og krydd. · landeyða (4): Duglaus maður sem nennir engu. |
| Létt | skapanorn (3): Ein af þremur gyðjum í norrænni goðafræði sem réðu örlögum. · slota (3): Að minnka og verða vægara. · tjasl (3): Verk sem er illa og óvandlega unnið. · helluhraun (3): Fremur slétt hraun með gárum og hraunreipum á yfirborðinu. · rýta (4): Að gefa frá sér hljóð eins og svín. |
| Miðlungs | talía (4): Búnaður með hjólum og reipi eða keðju til að lyfta þungu með litlum krafti. · miðdagur (4): Máltíð um miðjan dag, t.d. klukkan þrjú. · geldfé (5): Kindur sem ekki eignast lömb eða mjólka ekki. · lár (8): Trékassi sem ull og handavinna er geymd í. · rýta (4) |
| Erfitt | stroffa (6): Lítil lykkja eða hanki. · frumvaxta (8): Nærri því orðinn fullvaxinn. · hvítmaðra (8): Lágvaxin íslensk jurt með mjó blöð og greinóttar hvítar blómskipanir. · maríutása (8): Þunn, ljós skýjabreiða hátt uppi á himninum. · hengja (10): Fyrsti reykjarkeimur sem kemur í kjöt þegar farið er að reykja það. |

The 20 hard sample words from the first round are in the section [The first round](#the-first-round-the-hardest-words) below.

## How the list was built

1. **Round 1 (hardest words).**
   - 1,970 candidates were looked up through **málið.is**. They came from my own themed lists and from ÍNO senses labelled *gamalt, fornt, skáldamál, sjaldgæft, þjóðtrú* and the like.
   - A word was kept only if a source states its meaning: ÍNO, Blöndal, Íslensk orðsifjabók, Íðorðabanki or ISLEX.
   - 391 words were judged obscure for adults. They were then re-scored on the 1–10 scale; they score 4–10, mostly 6–9.
2. **Round 2 (re-review).** The 1,050 words that round 1 had rejected as "too well known for adults" were reviewed again under the new rules, with trade words now fair game. 634 were kept, mostly at scores 2–5.
3. **Round 3 (new words).**
   - 2,800 more candidates were sampled from the **ÍNO 2023 open dataset** (CC BY-SA 4.0), which has Icelandic definitions for about 56,000 entries.
   - The sample was spread across frequency bands, using word counts from the **Icelandic Gigaword Corpus frequency list** (CLARIN-IS, CC BY 4.0).
   - The **CEFR vocabulary lists** for Icelandic (CLARIN-IS, CC BY 4.0) were used to leave out basic A1–B1 vocabulary.
   - So were crude, medical, legal, computing and science-labelled entries.
   - 801 were kept, mostly at scores 2–5.
4. **Merge and audit.**
   - Duplicates were removed.
   - I dropped 41 borderline words during my own checks, for example:
     - too close to medical: *úfur*, *gotinn*;
     - a misleading spelling: *balli*, *stöður*;
     - a swear-word look-alike: *fokka*;
     - a definition resting on a synonym only: *þollur*.

**Rejected in total: 2,849.** Each has its reason in `rejected-candidates.json`.

| Reason | Words |
|---|---|
| TRANSPARENT | 1,110 |
| TOO_EASY | 1,001 |
| UNSUITABLE | 326 |
| BORING (jargon, bare species names) | 291 |
| NO_CLEAR_MEANING | 41 |
| DUPLICATE | 39 |
| dropped in my audit | 41 |

**Unverified: 136 words**, in `unverified-candidates.json`. 32 were not found anywhere; the rest were found, but no source states their meaning. They are not used.

### Words by source

| Source the definition rests on | Words |
|---|---|
| Íslensk nútímamálsorðabók (ÍNO) | 1,585 |
| Blöndal, Íslensk-dönsk orðabók (1920–24) | 156 |
| Íslensk orðsifjabók | 37 |
| Íðorðabankinn | 18 |
| ISLEX | 4 |

The scores, the child-friendly flags and the keep/reject calls are my and my review agents' estimates, not a native speaker's. A native speaker should look at the samples and move a word's score where it feels wrong. That is one number in `words.json`.

## The first round: the hardest words

These 20 words were drawn at random from the 391 kept in round 1. All are now in the Erfitt window.

| Word | Definition | Source |
|---|---|---|
| þingmannaleið (kvk.) | Forn mælikvarði á dagleið ferðamanns, um 37,5 kílómetrar. | [Íðorðabanki](https://malid.is/leit/%C3%BEingmannalei%C3%B0) |
| skafl (kk.) | Broddur á skeifu sem kemur í veg fyrir að hestur renni á ís. | [Blöndal](https://blondal.arnastofnun.is/faersla/247711) |
| stokkabelti (hk.) | Belti sett saman úr ferhyrndum málmplötum, oftast úr silfri. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/39578) |
| málnyta (kvk.) | Öll mjólkin sem fæst úr einum mjöltum á bænum. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/59952) |
| frolla (kvk.) | Húfa sem þykir ljót og ósmekkleg. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/13708) |
| gassi (kk.) | Karlfugl gæsar. | [Blöndal](https://blondal.arnastofnun.is/faersla/229249) |
| samur (kk.) | Hafið eða sjórinn, í fornum þulum. | [Orðsifjabók](https://malid.is/leit/samur) |
| denging (kvk.) | Það að þynna og skerpa egg á ljá. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/8089) |
| rjól (hk.) | Tóbaksblöð undin saman í langan streng. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/33529) |
| kollekta (kvk.) | Bæn sem prestur flytur fyrir altari á undan guðspjalli dagsins. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/24368) |
| krúkk (lo.) | Alveg peningalaus, blankur. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/24769) |
| ífæra (kvk.) | Stór krókur til að krækja í stóran fisk og draga hann um borð. | [Blöndal](https://blondal.arnastofnun.is/faersla/235304) |
| glýja (kvk.) | Stuttur og ótraustur þurrkur, dauft þerriveður. | [Blöndal](https://blondal.arnastofnun.is/faersla/230011) |
| barki (kk.) | Fremsti hluti báts eða skips, framstafninn. | [Blöndal](https://blondal.arnastofnun.is/faersla/221973) |
| byrðingur (kk.) | Stór bátur sem notaður var til vöruflutninga. | [Blöndal](https://blondal.arnastofnun.is/faersla/222564) |
| dvergur (kk.) | Stutt lóðrétt stoð í þakgrind torfbæjar sem styður mænisásinn. | [Íðorðabanki](https://malid.is/leit/dvergur) |
| leiðarþing (hk.) | Þing sem haldið var í héraði að loknu Alþingi til að segja frá störfum þess. | [Íðorðabanki](https://malid.is/leit/lei%C3%B0ar%C3%BEing) |
| stjóri (kk.) | Steinn sem notaður er sem akkeri fyrir litla báta. | [Blöndal](https://blondal.arnastofnun.is/faersla/251785) |
| hraunkarl (kk.) | Hár og oddhvass klettur sem rís upp úr hrauni. | [Blöndal](https://blondal.arnastofnun.is/faersla/233906) |
| árefti (hk.) | Borð eða hellur sem lagðar eru á rafta undir torfinu í torfþaki. | [ÍNO](https://islenskordabok.arnastofnun.is/ord/4301) |

### Rare senses of common words

181 words are flagged `sjaldgaef_merking`. Examples:
- *rjúpa* = hnykill
- *áróður* = róður á móti straumi
- *almenningur* = stærsta hólfið í skilarétt
- *búr* = matargeymsla
- *skytta* = skyttan í vefstól

They are great bluffs for adults. They are kept out of the Barnvænt level, and Phase 2 can show a hint for them or let the host leave them out.

## Terms of use of the sources

No dictionary website has a terms-of-use page, and arnastofnun.is has no general terms page, only a privacy policy. What is published:

| Source | What we used | Published terms | Attribution |
|---|---|---|---|
| ÍNO | Definitions (paraphrased) and links. The 2023 open dataset was used to find candidates. | CLARIN-IS dataset 2023-12: **CC BY-SA 4.0** (the licence header in the file). The February 2026 release changed to CC BY-NC-ND 4.0; we did not use it. | "Íslensk nútímamálsorðabók. Halldóra Jónsdóttir og Þórdís Úlfarsdóttir (ritstj.). Reykjavík: Stofnun Árna Magnússonar í íslenskum fræðum." + link |
| Blöndal | Danish glosses translated and paraphrased, and links | No licence published. The site says the digital edition is open to all free of charge. The 1920–24 text may be out of copyright (Sigfús Blöndal d. 1950); the 1963 supplement is not. | No format published. We cite "Íslensk-dönsk orðabók (Sigfús Blöndal), Stofnun Árna Magnússonar" + link. |
| ISLEX | Translations as evidence (4 definitions) | CLARIN-IS 2026: CC BY-SA 4.0 | "ISLEX. Þórdís Úlfarsdóttir (aðalritstj.). Reykjavík: Stofnun Árna Magnússonar í íslenskum fræðum." |
| Ritmálssafn | Citation counts, as a signal only | None published | "Ritmálssafn Orðabókar Háskólans. Stofnun Árna Magnússonar í íslenskum fræðum." |
| Íslensk orðsifjabók, Íðorðabankinn | Glosses (paraphrased), shown on málið.is | Not checked separately; I found no terms on málið.is | Name the work and link to málið.is |
| Málið.is | All round-1 lookups | No terms published. Its robots.txt allows all. | — |
| Icelandic Gigaword frequency lists ("Frequency lists for Icelandic 23.06") | Word counts, as a difficulty signal only | CLARIN-IS: **CC BY 4.0** (http://hdl.handle.net/20.500.12537/314) | Credit the dataset and the institute |
| CEFR vocabulary lists for Icelandic | Used only to exclude basic vocabulary | CLARIN-IS: **CC BY 4.0** (http://hdl.handle.net/20.500.12537/391) | Credit the dataset |
| BÍN | Not used for game content | Data CC BY-SA 4.0; copying the website is forbidden | Only needed if we show inflections |

**Can we use the list in a private game?** Yes, as far as anything published says. The list holds:
- headwords, which are facts;
- our own one-sentence paraphrases;
- a difficulty score;
- links back to the sources.

It copies no dictionary entries.

**Recommendations:**
1. Treat `words.json` as **CC BY-SA 4.0** (the file says so), because most definitions are paraphrased from ÍNO's BY-SA data.
2. Show a short credits line in the game naming Stofnun Árna Magnússonar and the dictionaries.
3. Keep the source link shown at each reveal.

**How the sites were queried:**
- Round 1's bulk lookups (about 2,000 requests, three at a time) went through malid.is, whose robots.txt allows crawling. While finding the API at the start, I also sent about ten manual requests straight to the Blöndal and ÍNO sites. Their robots.txt disallows bots other than the big search engines, so nothing further was sent there.
- Rounds 2 and 3 used only downloaded open datasets.

## Wording I'm not fully confident about

A native speaker should check these. The reason for doubt is in brackets.

- skjár: Þunn himna úr dýri sem höfð var í glugga í stað glerrúðu. (translated from Blöndal)
- spesía: Gömul silfurmynt, ríkisdalur sem jafngilti fjórum krónum. (my reading of "Speciesdaler")
- strekkingur: Kapp við að komast áfram eða ná á tiltekinn stað. (rare sense; most know the wind sense)
- völur: Ávöl brún sem myndast á egg bitjárns þegar hún hefur lagst. (technical)
- þurs: Lítill skýhnoðri á himni. (rests on one Orðsifjabók gloss)
- hjáseta: Það starf að gæta mjólkurfjár í haga að sumarlagi. ("mjólkurfé" for "kvíaær")
- jarðarhundrað: Gömul eining fyrir verðmæti jarðeignar, upphaflega metin í silfri og síðar í vaðmáli. (loose and long)
- kæfa: Þétt snjófok. (regional Blöndal sense)
- kaggi: Gamaldags hár hattur, þó heldur lægri en þeir algengustu. (ambiguous Danish)
- sili: Sá hluti reipis milli hagldanna sem byrðin hangir á. (technical)
- gullvöndur: Jurtategund af ætt maríuvanda. (thin; family name is my rendering)
- stakhenda: Enskur bragarháttur án ríms, fimm öfugir tvíliðir í hverri línu. ("öfugir tvíliðir" for iambs)
- flaga: Að gabba einhvern eða valda honum vonbrigðum. (one Blöndal gloss)
- basla: Að vera piparsveinn, lifa ókvæntur. (one Blöndal gloss; everyone knows the "strit" sense)

These definitions rest on a single short Orðsifjabók gloss: dalur, gola, eta, brestur, malda, goggur, hafur, drós, doppa and kölski (= krókur til að taka slátur upp úr sýrutunnu). They are faithful to that gloss, but a second source would be better.

Near-twins should not appear in the same game:
- sheep colours;
- the dolphins stökkull, hnýðingur and léttir;
- gíll and úlfur;
- the old time-of-day words (ótta, eykt, miðmorgunn, miðmundi, nón).

The `flokkur` tag lets Phase 2 spread the themes across a game.

## Files

- `words.json`: the 1,800 words and the proposed levels (`erfidleikastig`). Each word has:
  - `ord`, `ordflokkur`, `skilgreining`;
  - `erfidleiki`, `barnvaent`, `sjaldgaef_merking`, `flokkur`;
  - `heimild`, `tengill`, `malid`, `studningur` (the verbatim source fragment, for checking only);
  - `athugasemd`, `ovisst_mal`.
- `unverified-candidates.json`: the 136 unverified words, not used.
- `rejected-candidates.json`: the 2,849 rejected words, each with its reason.
- `tools/`: everything needed to repeat the work:
  - `fetch.sh`: the málið.is lookup;
  - `summarise.py`: extracts the evidence;
  - `RUBRIC.md` and `RUBRIC_v2.md`: the review rules, including the difficulty anchors;
  - `consolidate.py` and `consolidate_v2.py`: build the lists;
  - the candidate lists.

# Dulmál: language check

Everything players see is Icelandic: the word list in `data/ord.txt` and the page's text in `src/client/text.ts` (plus the not-invited page in `worker/index.ts`). This file records each word and phrase that was in doubt and what was decided. The review was done by Claude, not by a native speaker, so the items marked **check** are still worth a native speaker's look. `npm test` checks the word list's form.

## Orðalisti (word list)

| Word | Decision |
|---|---|
| Harmonikka | Kept. *Harmonikka* is the everyday spelling; *harmóníka* is also correct. |
| Kónguló | Kept. *Kónguló* is the common form; *könguló* is also used. |
| Mávur | Kept. *Mávur* and *máfur* are both standard. |
| Þrettándinn | Kept with the article: the day is always called *þrettándinn*, and *þrettándi* alone just means "thirteenth". |
| Hálendi | Kept. Usually said as *hálendið*, but the bare noun is correct and matches the other words. |
| Sjoppa, Nammi, Rúntur | Kept. Everyday words that adults 40–60 use and enjoy. |
| Víkingaklapp | Kept. The usual name for the clap, also called *húh-ið*. **Check.** |
| Fjallkona | Kept. Correct as one word (*fjallkonan* with the article). |
| Áramótaskaup | Kept. The full name; people often just say *Skaupið*. |
| Söngvakeppni | Kept. The bare noun is correct; the show is *Söngvakeppnin*. |
| Bóndi | **Changed** to *Sveit* (the countryside). *Bóndi* is an occupation, and the brief asked to avoid work-related words. |
| Snjóflóð, Jarðskjálfti, Eldgos | Kept. Part of Icelandic life and good for clues; nothing medical. |
| Skautar, Prjónar, Réttir, Páskar, Örlög, Tónleikar | Kept. Plural-only or usually plural nouns, kept on purpose. |

### Line breaks

These are split at `|` on small screens: Harmo\|nikka, Þrettán\|dinn, Höf\|rungur, Prin\|sessa, Kóngu\|ló, Ævin\|týri, Kon\|ungur, Vík\|ingur, Appel\|sína, Súkku\|laði, Rabar\|bari, Vett\|lingur, Drott\|ning, Blý\|antur, Gler\|augu, Hug\|rekki, Val\|kyrja, Að\|venta. All kept: each splits at a compound boundary, before a suffix that starts with a vowel (*kon-ungur*, *vík-ingur*), or between syllables, as the Icelandic spelling rules on word division (*orðaskipting*) allow. **Check** *Höf\|rungur*, *Þrettán\|dinn* and *Prin\|sessa*, where the syllable split is a judgement call.

## Texti á síðunni (page text)

| Phrase | Decision |
|---|---|
| *Sögumaður* / *Giskari* | Kept. *Sögumaður* suits the saga theme. *Giskari* is a regular formation (like *leikari*) and reads clearly in context, but it is not a common word. **Check.** |
| *Hraun á leik* / *Jökull á leik* | Kept. The usual way to say whose turn it is, as in chess (*hvítur á leik*). |
| *hjá Hrauni*, *hjá Jökli*; *Hrauns*, *Jökuls* | Kept. Correct dative and genitive (*hraun, hraun, hrauni, hrauns*; *jökull, jökul, jökli, jökuls*). |
| *2 gisk eftir* | **Changed** to *1 ágiskun eftir* / *2 ágiskanir eftir*. *Ágiskun* is the standard noun; *gisk* is colloquial. |
| *Giskið! Ýttu á orð.* | **Changed** to *Ýttu á orð til að giska.* The old line mixed the plural (*giskið*) and singular (*ýttu*) imperatives. |
| *Hve mörg orð á borðinu tengjast?* | **Changed** to *… tengjast vísbendingunni?* The verb needed an object. |
| *Það kann að vera útrunnið eða kóðinn rangur.* | **Changed** to *Því gæti hafa verið lokað, eða kóðinn er rangur.* *Útrunninn* is used for documents and food, not rooms. |
| *Aðeins þeir sem hefur verið boðið … komast inn.* | **Changed** to *Aðeins boðsgestir á icelander.net komast inn.* Shorter, gender-neutral, and avoids the case clash between *þeir* and *boðið*. |
| How-to line 5 | **Changed** *talan segir* to *talan segir til um*, the usual phrase for "the number indicates". |
| *fjarri* | Kept. A gender-neutral way to say a player isn't connected (*ótengdur/ótengd* would need a gender). |
| *Stokka upp liðin* | Kept. Natural for "shuffle the teams". |
| *Draugurinn*, *valdi drauginn* | Kept. Correct forms (*draugur, draug, draugi, draugs*). |
| *Hraun fann öll sín orð.* / *Hraun valdi drauginn og tapaði.* | Kept. A team name works as a singular subject. |
| *Ekki gefa nein merki!* | Kept. |
| *Hefurðu verið með áður, t.d. í öðru tæki? Veldu nafnið þitt:* | Kept. |
| *Ertu með sjónvarp eða skjávarpa? …* | Kept. |
| *Hraun fékk vísbendinguna „Sjór“ 2.* | Kept. |
| Not-invited page: *Dulmál er aðeins opið boðsgestum og þessum aðgangi hefur ekki verið boðið enn.* | Kept. Correct impersonal dative (*aðgangi … boðið*). |

| Walkthrough on the start and join pages (`src/client/text.ts`, `TOUR`) | Five short steps: *Tvö lið*, *Borð með 25 orðum*, *Sögumaðurinn sér lykilinn*, *Liðið giskar*, *Varist drauginn!*; buttons *Næsta*, *Til baka*, *Sjá aftur*; *Skref 2 af 5*. Is *Sjór 2 þýðir að tvö orð tengjast sjónum* clear, and *Rétt orð fær lit liðsins* natural? |
| Not-invited page, new pitch line | *Orðaleikur fyrir tvö lið, hvert á sínum síma: sögumaðurinn gefur eitt orð og tölu …* Natural? |

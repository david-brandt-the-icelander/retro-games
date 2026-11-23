# Dulmál: language check

Everything players see is Icelandic, written without a native speaker's review. These are the words and phrases I am least sure are correct and natural. Fix the word list in `data/ord.txt` and the page's text in `src/client/text.ts`; `npm test` checks the list's form.

## Orðalisti (word list)

| Word | Doubt |
|---|---|
| Harmonikka | Spelling: *harmonikka*, *harmóníka* or *harmónikka*? |
| Kónguló | *Kónguló* or *könguló*? |
| Mávur | *Mávur* or *máfur*? |
| Þrettándinn | The only word with the definite article (the day is usually called that); is *Þrettándi* better? |
| Hálendi | Usually said with the article, *hálendið*. |
| Sjoppa, Nammi, Rúntur | Colloquial; fine for the audience? |
| Víkingaklapp | Is this the natural name for the football "huh" clap? |
| Fjallkona | One word? |
| Áramótaskaup | People usually say *Skaupið*. |
| Söngvakeppni | Usually *Söngvakeppnin*. |
| Bóndi | An occupation; the brief asked to avoid work-related words. |
| Snjóflóð, Jarðskjálfti, Eldgos | Natural disasters; too grim for a party game? |
| Skautar, Prjónar, Réttir, Páskar, Örlög, Tónleikar | Plural-only or usually plural nouns, kept on purpose. |

### Line breaks

These are split at `|` on small screens. Please check the split points follow Icelandic hyphenation:
Harmo|nikka, Þrettán|dinn, Höf|rungur, Prin|sessa, Kóngu|ló, Ævin|týri, Kon|ungur, Vík|ingur, Appel|sína, Súkku|laði, Rabar|bari, Vett|lingur, Drott|ning, Blý|antur, Gler|augu, Hug|rekki, Val|kyrja, Að|venta.

## Texti á síðunni (page text)

| Phrase | Doubt |
|---|---|
| *Sögumaður* / *Giskari* | Role names for the clue-giver and guessers. *Giskari* especially: natural? |
| *Hraun á leik* / *Jökull á leik* | "It's Hraun's turn", borrowed from chess (*hvítur á leik*). |
| *hjá Hrauni*, *hjá Jökli*; *Hrauns*, *Jökuls* | Dative and genitive of the team names. |
| *2 gisk eftir* / *1 gisk eftir* | *Gisk* as a countable noun; would *2 ágiskanir eftir* be better? |
| *fjarri* | Label for a player who is not connected (chosen as gender-neutral). |
| *Stokka upp liðin* | "Shuffle the teams". |
| *Draugurinn*, *valdi drauginn* | The game-over word is called "the ghost". |
| *Hraun fann öll sín orð.* / *Hraun valdi drauginn og tapaði.* | Team names as singular subjects. |
| *Ekki gefa nein merki!* | Told to the clue-giver while their team guesses. |
| *Hefurðu verið með áður, t.d. í öðru tæki? Veldu nafnið þitt:* | Taking back a seat. |
| *Ertu með sjónvarp eða skjávarpa? Opnaðu tengilinn þar og veldu „Stór skjár“.* | |
| *Hraun fékk vísbendinguna „Sjór“ 2.* | |
| The eight lines of *Svona er leikið* (`HOW_TO` in `src/client/text.ts`) | Especially line 5: *Það má giska einu sinni oftar en talan segir, eða hætta fyrr.* |
| *Aðeins þeir sem hefur verið boðið í Dulmál á icelander.net komast inn.* | Invite hint in the lobby. |
| *Dulmál er aðeins opið boðsgestum og þessum aðgangi hefur ekki verið boðið enn.* / *Ef þér var boðið á öðru netfangi skaltu skrá þig inn með því.* | The page for a signed-in player without an invitation (`notInvited` in `worker/index.ts`). |

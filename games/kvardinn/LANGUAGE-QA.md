# Language check for a native speaker

Everything in Kvarðinn is in Icelandic, written by a non-native writer. Most of it should read naturally. The items below are the ones I'm **not confident** are correct, natural Icelandic. Please mark each one **OK**, give a better wording, or say **remove**. Cards are in [`data/kvardar.txt`](data/kvardar.txt); interface text is in `src/client/main.ts`, `src/client/text.ts` and `src/engine/game.ts`.

## Name of the game

The working name is **Kvarðinn** ("the scale"). Two alternatives:

- **Á milli** ("in between")
- **Nærri lagi** ("close enough, about right")

## Scale cards

| Card | Doubt |
|---|---|
| Kaffitýpa ↔ Tetýpa | Is "-týpa" for a kind of person acceptable here, or too slangy? |
| Gluggaveður ↔ Alvöru blíða | Does "alvöru blíða" read as the natural opposite of "gluggaveður"? |
| Heiti potturinn ↔ Kaldi potturinn | Should it be "Kalda karið"? |
| Norðlenskt ↔ Sunnlenskt | Natural pair, or is "Norðlenskt ↔ Reykvískt" better? |
| Ekkert jólalegt ↔ Mjög jólalegt | Would "Ójólalegt ↔ Jólalegt" be more natural? |
| Hversdags ↔ Spari | "Spari" on its own as a card end: fine? |
| Rólegt kvöld ↔ Mikið fjör | The two ends differ in form (adjective + noun vs. noun phrase). |
| Sunnudagskvöld ↔ Laugardagskvöld | Is the "feel" of the two evenings clear enough as opposites? |
| Brekkusöngslag ↔ Óperuaría | Is "brekkusöngslag" a real word? |
| Skemmtilegt einu sinni ↔ Skemmtilegt aftur og aftur | Natural? |
| Tröllslegt ↔ Álfalegt | Are both words natural adjectives? |
| Prúður ↔ Hrekkjóttur | Personality cards use the masculine form (also Feiminn, Nískur, Hógvær, Montinn, Varkár, Kaldhæðinn, Rólyndur, Skapstór, Þrjóskur, Svartsýnn, Þolinmóður, Alvörugefinn, Heimakær, Ævintýraþyrstur, Huglaus, Hugrakkur). Is generic masculine fine for a party game, or use neuter ("Feimið ↔ Félagslynt")? |
| Göfugt ↔ Lúalegt | Good opposites? |
| Alvörugefinn ↔ Galsafenginn | Is "galsafenginn" common enough? |
| Heimakær ↔ Ævintýraþyrstur | Natural pair? |
| Gerist daglega ↔ Gerist einu sinni á ævinni | Natural? |
| Ég myndi aldrei ↔ Ég geri það oft | Natural as card ends? |
| Stöðutákn ↔ Nytjahlutur | Natural pair? |
| Mamma myndi hneykslast ↔ Mamma yrði stolt | Mixed mood ("myndi" vs "yrði"): fine? |
| Má missa sín ↔ Má alls ekki missa af | Two different idioms; is there a better pair? |
| Tímasóun ↔ Tíma vel varið | Correct case in "Tíma vel varið"? |
| Ætti að banna ↔ Ætti að vera skylda | Natural? |
| Feimnismál ↔ Daglegt umræðuefni | Natural pair? |
| Kantað ↔ Kringlótt | Is "kantað" right for "angular", or "Kassalaga"? |
| Hundanafn ↔ Kattarnafn | "Hundanafn" or "hundsnafn"? |
| Hljómar íslenskt ↔ Hljómar útlenskt | Natural? |
| Ekki frétt ↔ Forsíðufrétt | Natural? |
| Túristar elska ↔ Íslendingar elska | "Túristar" vs "Ferðamenn"? |
| Gagnslaust í útilegu ↔ Ómissandi í útilegu | Natural? |
| Áunninn smekkur ↔ Ást við fyrstu sýn | Is "áunninn smekkur" an established phrase? |
| Gott í hófi ↔ Gott í miklu magni | Natural? |
| Snarl ↔ Heil máltíð | Natural? |
| Lélegt hljómsveitarnafn ↔ Frábært hljómsveitarnafn | Natural? |
| Falin perla ↔ Fjölsóttur ferðamannastaður | Natural? |

## Interface text

| Text | Where | Doubt |
|---|---|---|
| Team names **Aldan** and **Sólin** | everywhere | Good names? Both are singular, so verbs agree: "Aldan giskar", "Sólin fær 3 stig". |
| **vísirinn** for the shared pointer, **markið / leynimarkið** for the hidden target | everywhere | Right words? |
| á leik | score box of the team whose turn it is | Natural? |
| Aldan hallast að: ◀ vinstra megin | the other team's left/right choice before it is confirmed | Natural? |
| Aukagisk hins liðsins (vinstri/hægri); "Lið að 10 stigum, með aukagiski." | lobby | Is "aukagisk" (dative "aukagiski") a word people would understand? |
| Að 10 stigum | score bar | Natural for "first to 10 points"? |
| Hann eða hún segir eða skrifar vísbendingu sem á heima einmitt þar … | how-to, line 4 | Natural? Gender-neutral alternative? |
| Nálægt miðju marksins gefur 4 stig, svo 3 og 2. | how-to, line 6 | Natural? |
| Ræðið saman og færið vísinn | guessing team's instruction | Natural? |
| Þegar liðið er sátt ýtir þú á „Læsa ágiskun“. / … læsir ágiskuninni þegar hópurinn er sáttur. | guessing | Correct agreement? |
| Nú máttu ekki hjálpa! Bíddu og sjáðu hvar vísirinn lendir. | clue-giver while the team guesses | Natural? |
| Fylgist með. Á eftir giskið þið hvort markið sé vinstra eða hægra megin við vísinn. | other team while guessing | Natural? |
| Beint í mark! / Mjög nálægt! / Nálægt! / Því miður, ekkert stig | the reveal | Natural? |
| Aldan giskaði rétt og fær 1 aukastig. / Aldan giskaði rangt. | the reveal | Natural? |
| Næst gefur vísbendingu: Anna | the reveal | Natural? |
| Þið fenguð 27 stig / af 40 mögulegum. | co-op end | Natural? |
| Þú getur ekki fjarlægt sjálfa(n) þig. | error | OK to use "sjálfa(n)"? |
| Tengd(ur) / Ekki tengd(ur) | tooltip on the online dot | OK? |
| Hætta og fara í biðsal | host menu | Is "biðsalur" good for the lobby? |
| Stór skjár (sjónvarp) | lobby link to the TV view | Natural? |
| Ertu þegar í leiknum? Ef þú skiptir um tæki eða datt út, ýttu á nafnið þitt | join screen | Mixed tenses ("skiptir", "datt"): natural? |
| Bíðum eftir að allir komi inn. Anna hefur leikinn. | lobby, non-host | Natural? |
| Sleppa þessari umferð? Sama lið fær nýja umferð. | host confirm | Natural? |

# Brief: Icelandic category lists for two original party games

Players are native Icelandic speakers: adults, sometimes with children. Write ORIGINAL content in correct Icelandic
(þ, ð, æ, ö, accents). Do not copy or imitate any published game's cards; invent your own topics. Prefer an Icelandic
flavour where natural (Icelandic nature, food, folklore, places, culture, everyday life) mixed with universal topics.
Avoid: sex, crude humour, illness/medicine, death, violence, drugs/alcohol-heavy topics, politics, religion-heavy topics,
living real people, brands/trademarks.

## A. Topic grids (outsider game) — file "grids"
In the outsider game, everyone except one secret outsider sees a topic and one secret word from a 4×4 grid of 16 words
on that topic. Players give one-word associations; the outsider, who sees only the topic, must blend in.
Each grid: a short topic title (1–3 words, e.g. "Á ströndinni", "Íslenskir fuglar", "Í eldhúsinu") and EXACTLY 16
distinct items that:
- every adult in the target group knows (children too, if "barnvaent");
- are all at a similar level of specificity and clearly belong to the topic;
- are single words where possible (short phrases allowed only if they are the normal name, e.g. "heitur pottur");
- are written as base forms (nominative singular; plural only if that is the normal form, e.g. "skæri");
- are distinct enough that a one-word clue can point at one but could plausibly fit several (good for bluffing).
Fields per grid: "efni" (topic), "ord" (16 strings), "barnvaent" (bool), "erfidleiki" (1 easy – 3 hard, how specialist
the knowledge is), "flokkur" (theme tag).

## B. Category prompts (category race game) — file "categories"
In the race game, two players' symbols match and each must shout an example of the category on the OTHER player's card
before them. A prompt must have MANY valid answers (at least ~15 that an adult could name instantly) so it works under
time pressure; vary from easy to tricky.
Each prompt: "flokkur_texti" — short category text as it appears on a card (1–4 words, e.g. "Fiskur", "Eitthvað
gult", "Íslenskt fjall", "Hljóðfæri", "Orð sem rímar við 'hús'", "Eitthvað í ísskápnum"), "daemi" — 8 valid example
answers (for the judge; base forms), "barnvaent" (bool), "erfidleiki" (1 easy – 3 hard), "tegund" one of: hlutir,
dýr_og_jurtir, matur, staðir, fólk_og_störf, íslenskt, menning, orðaleikir, annað.
Use varied prompt styles: plain categories ("Fugl"), properties ("Eitthvað kringlótt"), places ("Eitthvað í
sundlauginni"), Icelandic culture ("Íslenskur jólasiður"), and a few word-play prompts ("Orð sem byrjar á 'sk'").
Proper names (places, rivers, mountains, towns, fictional characters, historical sagas) are fine as ANSWERS where the
category calls for them, but never living people.

## Output
Write a JSON object to the output path given in your task with Python json.dump(..., ensure_ascii=False, indent=1).
Self-check before saving: 16 unique items in every grid; no topic repeated; 8 examples per category; no category
repeated; spelling. Report only: counts, and up to 5 items you are unsure about (spelling or fit).

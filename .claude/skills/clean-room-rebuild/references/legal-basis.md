# Legal basis and grey areas

Not legal advice. This is the reasoning the skill relies on, so you can explain decisions to the user and spot cases that need a human.

## What copyright protects in a game

| Element | Protected? | Notes |
|---|---|---|
| Rules, mechanics, turn structure, scoring | No | Ideas and functionality. *Nova v Mazooma* [2007] EWCA Civ 219: "an idea consisting of a combination of ideas is still just an idea". |
| What the program does (behaviour, formulas) | No | *SAS Institute v World Programming* C‑406/10 (CJEU 2012): functionality, programming language and data formats are not protected. |
| Source / object code | Yes | Including translations into another language: a port that follows the original routine by routine is an adaptation (derivative work). |
| On-screen text, manual, messages | Yes, as literary works | Single words and very short generic phrases are not, but a table of dozens of messages is. |
| Graphics, sprites, fonts, screen layouts | Yes, as artistic works | Hardware constraints (palette, grid) are not. |
| Music and sound effects | Yes | Melodies are protected even if re-recorded. |
| Level layouts, maps | Usually yes | Expressive arrangement, especially hand-designed rooms. |
| Title, character and brand names | Not by copyright, but possibly by trade mark / passing off | Generic words (e.g. "Ship of the Line", "Harbour Master") are weak marks; distinctive ones (e.g. "Miner Willy", "Dizzy") may still be registered and in use. |
| Numeric balance tables | Grey | Facts and parameters are generally not protected, but a large compilation copied verbatim in its original layout can be argued as expression (and in the EU/UK, database right lasts only 15 years, so it has lapsed for 1980s games). Restate in your own structure. |

US caution: *Tetris Holding v Xio Interactive* (D.N.J. 2012) found infringement where a clone reproduced the overall visual look (board size, piece shapes and colours, display of next piece, etc.) very closely. Aim for the same play, not the same screenshot.

## Duration

- UK/EU: literary and artistic works last for the author's life + 70 years, to the end of that calendar year. The author is the human programmer/artist even when an employer owns the copyright.
- US: works made for hire, 95 years from publication (so 1982–1985 games run to 2077–2080).
- Result: no commercial game from the 8-bit era is in the public domain, regardless of whether the company still exists.

## Who owns it now

1. Read the copyright line in the game itself (BASIC listings often have it in a `REM` or `PRINT`) and in the manual/inlay.
2. Individuals named personally (e.g. "© Richard Shepherd 1982", "© K. J. Toms 1982") often still own the rights or their estates do.
3. Companies: check Companies House (UK) for dissolution. Rights of a dissolved UK company that were not assigned before dissolution pass to the Crown as *bona vacantia*; the Government Legal Department's Bona Vacantia Division can sometimes license or sell them.
4. Many catalogues were sold on (e.g. Ultimate → Rare → Microsoft; Ocean → Infogrames → Atari). Check recent re-releases (compilations, mini consoles, collections such as Rare Replay, streaming services such as Antstream) — whoever licensed those is the active owner.
5. Licensed properties add a second owner (TV shows, films, books, comics: e.g. The Hobbit, Popeye, Trap Door). Treat those as high risk.

## When to recommend permission instead of (or as well as) a rewrite

- The rights holder is an identifiable individual who is reachable — a friendly email asking for permission to publish a free fan remake often succeeds and removes all doubt.
- The user wants to keep the original title, names, text or art.
- The game is tied to a licensed property or a company that still actively sells it.

## What "not affiliated" credits do and don't do

A factual credit ("Inspired by X by Y") is fine and good manners. It does not license anything: it doesn't make copied text or art acceptable, and recreating the original's credit or title screen is reproducing their branding, which is the opposite of disclaiming affiliation.

## Fan disassemblies and listings

Fan disassemblies (SkoolKit projects etc.) and BASIC listings extracted from tapes are fine to *read* to understand behaviour. They carry no licence from the rights holder, so using them doesn't grant any rights: anything copied from them (text, data tables, code structure) is still the original's expression.

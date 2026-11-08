# Gambit: game design document

An original chess game, not a remake, so the clean-room phases of `create-retro-game` (provenance, behaviour spec, overlap checks) don't apply: chess's rules belong to nobody, and nothing here copies another chess program's look or text. This document keeps the parts of that process that do apply: the pillars, the screens and the decision log.

## Pillars

1. **Stylish, not retro.** A quiet, dark interface in charcoal and ivory with one warm gold accent; Playfair Display italic for titles, Inter for reading. A 3D table under soft key, rim and warm fill lights: ivory and glossy obsidian pieces on a slate and bone board with a thin gold inlay.
2. **Play anyone, any time.** Invitations go to an email address; a game waits as long as it needs to. The computer needs no account.
3. **A game is a conversation.** Moves and chat share one transcript, with times, kept forever and replayable.
4. **The server is the referee.** Online moves are checked on the server.

## Screens

Home (title over a slowly turning board) · Sign-in · Computer set-up · Lobby (invite, invitations for you, your games, waiting for an answer, contacts) · Contact (record and every game together) · History · Game (online, computer) · Replay. Each is specified in [UI-DESIGN.md](UI-DESIGN.md), the table and pieces in [ART-BIBLE.md](ART-BIBLE.md), and how to check an implementation against the reference renders in [DESIGN.md](DESIGN.md).

## Decision log

| Date | Decision | By |
|---|---|---|
| 2026-11-08 | Two-player online chess in this repo: OAuth login, invitations by email, contacts and history, TypeScript, plus Stockfish with a choice of strength. | Owner |
| 2026-11-08 | First version: an 8-bit pixel-art web page ("Pixel Gambit"). | Claude |
| 2026-11-08 | **Not a retro game:** very stylish, made in **Godot 4 as a 3D game**. Invitations by email; multiplayer requires OAuth sign-in for both players (so email, name and profile picture are known). Contacts are the people you have played, with your history against each. A chat area; chat and moves go into one transcript during play and into the game's history, with timing; historical games can be replayed. | Owner |
| 2026-11-08 | Godot 4.7.2, GDScript, Compatibility renderer (WebGL 2), single-threaded web export (no cross-origin isolation needed). All models made in code; no art files. | Claude |
| 2026-11-08 | Kept from the first version: the Worker, D1 and a Durable Object per game; Google and GitHub sign-in; Stockfish 19 at eight strengths (now driven from the page through a small JavaScript bridge); playing the computer without signing in. Dropped: pass & play on one screen, and adding contacts by hand (contacts are now only people you have played). | Claude, open for the owner |
| 2026-11-08 | Working title **Gambit**; slug and path stay `chess` (`/retro/chess`). | Claude, open for the owner |
| 2026-11-08 | Replays play back at the game's own pace, sped up 1×, 4× or 16×, with pauses capped at 3 s. | Claude |
| 2026-11-08 | The design is written down to be built from: DESIGN.md (acceptance), UI-DESIGN.md, ART-BIBLE.md, design-tokens.json, and 23 reference renders. Writing it fixed four things the renders showed: the lights now turn with the camera (seen from Black the board was glaring), the coordinates read upright from either side, the draw-offer banner puts its buttons under the text, and the transcript shows day headings with plain HH:MM times. Also "1 win" (not "1 wins"). | Owner asked for the designs in the repo; Claude |
| 2026-11-08 | Answers to the implementer's questions on the design: (1) the top bar's 72 px include its 18 px top margin, so it doesn't overlap the game panel at 84 px; (2) Black's moves are numbered `N…` everywhere, the replay heading included; (3) **Remove from contacts** asks "Sure?" like Resign; every Danger button does; (4) the move hints and the check warning do **not** glow: they are flat unshaded marks, as in the reference renders; (5) the shadow filter is Godot's value 3, which is *medium*; the board coordinates sit at y = 0, level with the squares; chat names keep their case; the 1×/4×/16× pace chips don't stop a playing replay; the result at the end of a replay is gold. The documents and the code now say the same. | Claude (designer) |
| 2026-11-08 | The game built to the written design. Points the design leaves open, decided in the build: the table turns only behind the title screen and rests behind the list screens; a replay shows `Replay · HH:MM` until the first move (also past a chat before it); dropping a piece back on its own square is just putting it down (no *illegal* sound); a fifth sound replaces the one that started longest ago, and **Sound off** also stops what is playing; the transcript keeps the move being looked at in view; an invitation link you sent yourself, still open, says nothing (it is under **Waiting for an answer**). Reference renders 01–03, 05–11, 16, 18, 19, 21 and 22 re-rendered to match. | Claude |
| 2026-11-08 | No clocks: correspondence-style games. Email only for new invitations, not for each move. | Claude, open for the owner |

## Non-goals (for now)

Clocks and time controls, ratings, spectators, puzzles, analysis with the engine, move notifications by email or push, phone-sized layouts (the game screen needs about 1000 px of width).

# Pixel Gambit: game design document

An original chess game, not a remake, so the clean-room phases of `create-retro-game` (provenance, behaviour spec, overlap checks) don't apply: chess's rules belong to nobody, and nothing here is copied from another chess program's look or text. This document keeps the parts of the process that do apply: the pillars, the screens, and the decision log.

## Pillars

1. **Feels like an 8-bit game.** Pixel-art pieces at 16×16, a board drawn at 152×152 pixels and scaled in whole pixels, a pixel font for headings, square-wave sound, scanlines.
2. **Play anyone, any time.** The computer at eight strengths needs no account. Friends are one email address away, and a game waits as long as it needs to.
3. **The server is the referee.** Online moves are checked on the server with the same rules code as the browser.

## Screens

Title · Computer set-up · Game (computer, pass & play, online, replay) · Sign-in · Lobby (challenge form, challenges for you, games in play, waiting for an answer, contacts) · History.

## Decision log

| Date | Decision | By |
|---|---|---|
| 2026-11-08 | Owner asked for two-player online chess in this repo: OAuth login, challenges by email address, remembered contacts and game history, nice graphics, TypeScript, and a one-player mode against an open-source engine with a choice of strength. Asked for the whole thing at once ("build it"), so phases ran back to back. | Owner |
| 2026-11-08 | Working title **Pixel Gambit**, slug and path `chess` (`/retro/chess`). Alternatives: *Knight Shift*, *Check Mate 8-Bit*. | Claude, open for the owner |
| 2026-11-08 | Engine: **Stockfish 19**, lite single-threaded WebAssembly build (1.8 MB, no cross-origin isolation needed). GPL-3.0, shipped as separate files with its licence; MPL-2.0 allows combining with GPL. Strength via Skill Level 0–20 plus a depth or time limit, in eight named steps. | Claude |
| 2026-11-08 | Sign-in, contacts and games live in this game's own Worker (D1 + one Durable Object per game), not the games hub's `/multiplayer` lobby. The hub's lobby is for real-time sessions where everyone is waiting at once; chess challenges are asynchronous and addressed to an email that may not have signed in yet. The hub's code (`recreations`) couldn't be read from this session to reuse its sign-in. | Claude, open for the owner |
| 2026-11-08 | Sign-in with **Google and GitHub** (OAuth code flow with PKCE); a user is a verified email address. | Claude |
| 2026-11-08 | Challenge emails through **Resend**, optional. Cloudflare's own `send_email` binding only sends to verified addresses, so it can't email strangers. Without a key, challenges wait in the lobby and the challenger gets a link to send. | Claude |
| 2026-11-08 | No clocks: online games are correspondence-style. | Claude, open for the owner |
| 2026-11-08 | Email notifications only for new challenges, not for each move, to avoid spam. The lobby and an open game update live; the tab title shows "Your move". | Claude, open for the owner |

## Non-goals (for now)

Clocks and time controls, ratings, spectators, chat, puzzles, analysis with the engine, move notifications by email or push.

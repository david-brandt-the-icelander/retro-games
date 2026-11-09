# Gambit

![A finished game: the board, the players, and the transcript of moves and chat](docs/screenshot-game.png)

*Chess, beautifully.* A 3D chess game made in Godot 4 for the web. Invite a friend by email and play at your own pace, chatting as you go, or play Stockfish at eight strengths. Every game, with its moves, chat and timing, is kept and can be replayed.

It lives at <https://games.icelander.net/retro/chess/>. Like every game on games.icelander.net it needs a sign-in, with Google or GitHub, through icelander.net's login service (`accounts.icelander.net`): one sign-in for the whole host, made once (see **Sign-in** below).

## How to play

- **Play a friend.** Sign in with Google or GitHub, type a friend's email address, choose your colour and send the invitation. They sign in with that address (also through Google or GitHub) and find it waiting under **Friends**; if email sending is set up they also get an email, and either way you get a link to send them. Once they accept, the game is on: moves and messages appear on both screens at once, and either of you can leave and come back days later. **Offer draw**, **Resign**, and afterwards **Rematch** (colours swapped).
- **Chat.** During the game, and after it, messages go into the same transcript as the moves.
- **The transcript.** Every move, message, draw offer and result, in order, with the clock time it happened and how long each move took. Click a move to look at that position; **Back to the game** returns.
- **Contacts.** Everyone you have played is kept under **Friends** with their name, email and profile picture from Google or GitHub, and your record against them. Open one to see every game you have played together and invite them again.
- **History and replays.** **History** lists every finished game. Open one to replay it: step through with **Back** and **Next**, drag the slider, or press **Play** to watch it at the pace it was played, sped up 1×, 4× or 16× (pauses are capped at three seconds).
- **Play the computer.** Pick a strength and a colour. Stockfish runs in your browser. Your game is kept on the device, so a reload carries on where you were; **Take back** undoes your last move and the computer's answer. Finished games go to your history (on the server when signed in, on the device otherwise).

**Moving:** click a piece, then where it goes (gold dots show the moves, rings show captures), or drag it. Drag the empty table (or the right mouse button) to turn the camera; the wheel zooms. **Turn the board** shows the other side.

### The computer's strengths

| | Name | Stockfish Skill Level | Search |
|---|---|---|---|
| 1 | Pawn Pusher | 0 | depth 1 |
| 2 | Weekend Player | 3 | depth 2 |
| 3 | Club Novice | 6 | depth 4 |
| 4 | Café Regular | 9 | depth 6 |
| 5 | Club Captain | 12 | depth 9 |
| 6 | County Champion | 15 | depth 12 |
| 7 | Master | 18 | 1 second |
| 8 | Stockfish | 20 | 2 seconds |

The ratings shown in the game are rough guides, not measured.

## Design

The whole design (every screen and state, the 3D table and pieces with their exact dimensions, colours, type, motion and sound) is in [docs/DESIGN.md](docs/DESIGN.md), with reference renders of every state in [docs/screens/](docs/screens/) and on one [contact sheet](docs/contact-sheet.png). The game can be built from `docs/` alone; `scripts/reference/` recreates the reference scenario and renders it for comparison.

## How it works

```
godot/                  the game (Godot 4.7, GDScript, Compatibility renderer for WebGL 2)
  chess/rules.gd        the rules: moves, SAN, check, mate, draws (tested against perft counts)
  scripts/board3d.gd    the table: board, lights, camera, animation, picking pieces with the mouse
  scripts/pieces.gd     the pieces, modelled in code: turned profiles, and a lofted knight's head
  scripts/main.gd       the screens: home, sign-in, computer set-up, lobby, contact, history
  scripts/game_screen.gd  a game: players, transcript, chat, draw offers, replay
  scripts/api.gd        the server's API, the live WebSocket, profile pictures, the page bridge
  scripts/ui.gd, avatar.gd, sfx.gd   the look (theme, fonts), round avatars, synthesised sounds
  web_shell/shell.html  the page the web export runs in
bridge/                 TypeScript for that page: boots the engine, Stockfish in a Web Worker,
                        and what only the page can do (navigate to sign-in, the clipboard, the title)
shared/                 TypeScript shared by the Worker and its tests: rules (chess.js), API types
worker/                 the Cloudflare Worker
  index.ts              routes; joins the engine's .wasm, which is stored in two parts (see below)
  auth.ts               the host's sign-in (vendor/icelander-auth and the login service), mapped to Gambit's own users; profile pictures
  api.ts                lobby, invitations, contacts, games, history, avatars
  room.ts, actions.ts   a Durable Object per online game: moves and chat, one at a time, live
  db.ts, schema.sql, mail.ts
```

- **Who you are.** The person signed in to games.icelander.net, as icelander.net's login service says on every request: a verified address from Google or GitHub (the same address through either is the same person, and one person may have several addresses). Gambit keeps its own row per player, keyed by address, for games, contacts and history; a person plays as the first of their addresses Gambit already knows. Name and picture come from the login service. Pictures are fetched through the Worker (`api/avatar/ID`, only from Google's and GitHub's image hosts), so the game loads everything from its own origin. The cookie is the host's `games_session` (`HttpOnly`, `Secure`, `SameSite=Lax`, games.icelander.net only); writes must be JSON from this origin.
- **The server decides.** Every online move and message goes through the game's Durable Object, which checks it (with chess.js) and saves it in D1 as the game's state plus a new transcript entry (`game_events`: when, who, what). Both players get the whole game over a WebSocket after every change. The game shows your move at once; the server confirms it or puts it back. Games against the computer are checked too before they go into your history: legal moves, a finished game, and times that only go forward.
- **What is stored:** users (email, name, picture URL), invitations (to an email address), games (moves, result) with their transcripts (moves, chat, offers, times), and contacts.
- **The engine file.** Godot's WebAssembly engine is 39.5 MB, and Cloudflare serves static files of at most 25 MiB, so the build stores it as `index.wasm.0` and `index.wasm.1` and the Worker streams them back as one `index.wasm`.

## Develop

You need Node 22 and [Godot 4.7.2](https://godotengine.org/download) with its web export templates (set `GODOT` to its path if it isn't on the PATH as `godot`).

```bash
npm install
npm test                 # TypeScript: rules, transcript actions, and the whole API on an in-memory SQLite
npm run test:godot       # GDScript: move generation (perft), SAN, mate and draws; the text formats
cp .dev.vars.example .dev.vars          # DEV_LOGIN=1: sign in as any email, for testing two players
npx wrangler d1 execute chess --local --file worker/schema.sql
npm run dev              # exports the game, then wrangler dev at http://localhost:8787/retro/chess/
```

With `DEV_LOGIN=1` the sign-in screen offers a development sign-in that takes any address; use two browsers (or a private window) to play yourself. Never set it in production.

You can also run the game from the Godot editor or the command line against the dev server, signed in as anyone: `godot --path godot -- --dev-email=you@test.io`. Development switches (desktop only): `--server=URL`, `--goto=setup|lobby|history|computer|game`, `--id=GAME`, `--moves=e2e4,e7e5`, `--click=X,Y;X,Y`, `--shot=file.png --shot-after=SECONDS` (a screenshot, then quit). The computer opponent only runs in the browser.

## Sign-in

Gambit used to sign people in itself (Google and GitHub OAuth in `worker/auth.ts`, a `chess_session` cookie, a `sessions` table). It now uses games.icelander.net's one sign-in, through icelander.net's login service; the design is in that repository's `docs/accounts.md`, and this host's side in the `recreations` repository's `docs/SIGN-IN.md`. `/retro/chess/auth/login/<provider>` and the old callbacks go to the host's `/auth/sign-in`; `auth/logout` signs out of games.icelander.net.

Moving over keeps every player's games, contacts and history: they stay keyed by address in Gambit's `users` table. The players are also imported into the login service so they are listed on its admin page (export them read-only first, for its import):

```bash
npx wrangler d1 execute chess --remote --json --command "SELECT email, name, picture, created FROM users" > gambit-users.json
```

After the move, and once sign-in works, delete the old secrets and the sessions table:

```bash
npx wrangler secret delete GOOGLE_CLIENT_ID
```

```bash
npx wrangler secret delete GOOGLE_CLIENT_SECRET
```

```bash
npx wrangler secret delete GITHUB_CLIENT_ID
```

```bash
npx wrangler secret delete GITHUB_CLIENT_SECRET
```

```bash
npx wrangler d1 execute chess --remote --file worker/retire-sessions.sql
```

and remove the old redirect URIs `https://games.icelander.net/retro/chess/auth/callback/google` (Google Cloud Console) and `…/callback/github` (the GitHub OAuth app; or delete that app, since the login service has its own).

## Deploy

One-time set-up (owner actions):

1. `npx wrangler d1 create chess`, put the id in `wrangler.jsonc`, then `npx wrangler d1 execute chess --remote --file worker/schema.sql`.
2. Sign-in: put icelander.net's login service's public keys into `ACCOUNTS_JWKS` in `wrangler.jsonc` (the `accounts` Worker must be deployed first; its service binding is already in `wrangler.jsonc`). No OAuth secrets belong here.
3. Optional, to email invitations: a [Resend](https://resend.com) API key (`npx wrangler secret put RESEND_API_KEY`) and a verified sender in `MAIL_FROM` in `wrangler.jsonc`. Without it invitations still work; the inviter sends the link.

Then `npm run deploy`.

## Credits and licences

Gambit's code and models are MPL-2.0, like the rest of this repository. It runs on [Godot Engine](https://godotengine.org) (MIT). It ships Stockfish 19 (the lite, single-threaded WebAssembly build from [stockfish.js](https://github.com/nmrugg/stockfish.js)), which is GPL-3.0; its licence is served beside it at `engine/COPYING.txt`. The fonts Inter and Playfair Display are SIL OFL 1.1, with their licences in `godot/fonts/`. The server checks moves with [chess.js](https://github.com/jhlywa/chess.js) (BSD-2-Clause).

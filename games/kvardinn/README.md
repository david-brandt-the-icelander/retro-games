# Kvarðinn

An original Icelandic party game for 4–8 players (up to 12), some in the same room and some remote. Everyone joins from one shared link on their own phone or laptop: a name, a team, and play. No sign-in, no install.

A scale card shows two opposites ("Kalt ↔ Heitt"). The app hides a target somewhere on the 0–100 scale; only that round's clue-giver sees it. They say or type a clue, their team drags a shared pointer (it moves live on every device) and a designated player locks it in. The other team may guess whether the target is left or right of the pointer for 1 point. The reveal scores 4 / 3 / 2 points for the centre and outer bands. First team to 10 wins (5, 10, 15 or 20 in the lobby). In **Allir saman** mode everyone guesses together for 5, 10 or 15 rounds and tries to beat the room's best score.

Inspired by the "guess where a clue sits between two opposites" genre; the name, look, cards, scale design and every word are its own.

## Playing

1. Open the game and press **Stofna nýjan leik**. The lobby shows a four-letter code, the link and a QR code.
2. Send the link (or show the QR code); each player types a name and picks **Aldan** (blue) or **Sólin** (amber). The host can shuffle the teams, move or remove players, change the settings and add their own scales.
3. Optional: open **Stór skjár (sjónvarp)** on a TV or projector (`#CODE/skjar`). It never shows the target before the reveal.
4. Press **Hefja leik**. Each team needs at least two players (co-op: two players in all).

A player who refreshes, loses signal or locks their phone gets the same seat back automatically (the seat is remembered in that browser). On a different device, the join screen lists seats nobody is using: tap your name. If the host drops out, the earliest-joined player who is still connected gets the host's buttons until the host returns. The host can skip a round (the same team plays again) if the clue-giver disappears.

## Hosting

The game is one Cloudflare Worker with a Durable Object per room. Rooms are deleted after two idle days.

**On icelander.net** (`wrangler.jsonc`, route `icelander.net/games/fresh/kvardinn*`): a merge to `main` deploys it, like the other games. Unlike them, it has **no sign-in**, because players must join from a link without logging in; that is an open decision for the owner (`.dev/decisions.json`).

**On your own Cloudflare account** (free plan is enough):

```bash
npm install
```

```bash
npx wrangler login
```

```bash
npm run build && npx wrangler deploy --env standalone
```

Wrangler prints the address, e.g. `https://kvardinn.<your-subdomain>.workers.dev/`. Open it, create a game, and share the link the lobby shows.

**On your own computer, for players on the same Wi-Fi** (no account needed):

```bash
npm install && npm run dev
```

Then open `http://<your-computer's-IP>:8787/` on each phone. Remote players can't reach this one.

## Editing the scale cards

The built-in cards are in [`data/kvardar.txt`](data/kvardar.txt): one card per line, `Vinstri ↔ Hægri`, with `#` comment lines and category headings. Edit it with any text editor, run `npm test` (it checks every line, repeats and length) and deploy. Hosts can also add their own scales in the lobby (**Eigin kvarðar**) and play only those.

The cards and the interface text that a native speaker should check are listed in [`LANGUAGE-QA.md`](LANGUAGE-QA.md).

## Files

| Path | What it does |
|---|---|
| `src/engine/game.ts` | The rules as pure functions: seats, rounds, turns, scoring, and `viewFor`, which hides the target from everyone but the clue-giver until the reveal. |
| `src/engine/cards.ts` | Reads `data/kvardar.txt`. |
| `worker/index.ts` | The Worker: `POST {BASE}/api/rooms`, the room WebSocket at `{BASE}/ws/CODE`, and the page from `dist/`. |
| `worker/room.ts` | The `Room` Durable Object: holds one game in storage, talks to every device over hibernatable WebSockets, sends each its own view. |
| `src/client/` | The page: `main.ts` (screens), `scale.ts` (the scale and the draggable pointer), `net.ts` (reconnecting connection and saved seat), `sound.ts`, `text.ts` (how-to text). |
| `public/` | `index.html`, `style.css`, `icon.svg`. `build.mjs` copies them to `dist/` and bundles the page into `dist/app.js`. |
| `test/` | `npm test`: the rules (including that the target never reaches a non-giver's view) and the card file. `npm run test:e2e`: plays a round in Chromium with four phones and a TV against a running `wrangler dev`, watching every WebSocket frame for a leaked target. |

## Develop

```bash
npm install
npm test
npm run dev
```

`npm run dev` serves the game at `http://localhost:8787/`. With it running, `npm run test:e2e` (needs Playwright: `npm i -g playwright`) plays a round; `SHOTS=dir` saves screenshots.

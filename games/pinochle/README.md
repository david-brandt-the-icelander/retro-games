# Pinochle

> **Live at [icelander.net/games/pinochle](https://icelander.net/games/pinochle/)** (the old address, /games/fresh/pinochle, redirects there), solo against bots only, for invited players only (role `games:pinochle`, granted at icelander.net/private/admin). `worker/index.ts` is a Cloudflare Worker that serves `public/` (built into `dist/` by `build.mjs`) behind the site's sign-in; `npm test` checks it, and the owner publishes it from their own machine with `npm run deploy` (nothing deploys from GitHub). The Node server in `server/` is not deployed, so the online buttons are hidden (`ONLINE` in `public/app.js`); online rooms would need the server ported to a Durable Object.

Four-player partnership auction pinochle for phones and browsers. Installable as a PWA (Add to Home Screen).

- **Solo** — you + 3 bots, runs entirely in the browser (works offline once loaded).
- **Online** — create a room, share the 4-letter code/link, pick seats (partners sit across). Empty seats are played by bots; a player who disconnects is replaced by a bot until they rejoin (same browser).

```bash
cd server
npm install
npm start          # http://localhost:3000   (PORT=... to change)
npm test           # 2000 bot-vs-bot games through the engine
```

Phones on the same Wi-Fi: open `http://<your-computer-ip>:3000`. For internet play deploy `server.js` anywhere that runs Node and supports WebSockets (Fly, Render, Railway…) — use HTTPS so the PWA installs.

## Rules implemented
48-card deck (A 10 K Q J 9 ×2 per suit). Bidding from 20 (one round of raises until all but one pass; if all pass the dealer is stuck at 20). Bidder names trump; partner passes 3 cards to the bidder, who passes 3 back. Meld: run 15 / double run 150, royal marriage 4, marriage 2, dix 1, pinochle 4 / double 30, aces·kings·queens·jacks around 10·8·6·4 (×10 for double). Play: must follow suit, must head the trick, must trump (and over-trump) if void. Counters A/10/K = 1 each + last trick = 25. A team that wins no trick scores nothing; a bidder who falls short loses the bid. First to 150 wins (bidder wins ties).

Tunables live at the top of `public/engine.js` (`TARGET`, `MIN_BID`, `MAX_BID`, meld values in `meldOf`).

## Layout
- `public/engine.js` — rules, bots, `Table` (turn/bot timers). Shared by browser and server.
- `public/app.js`, `style.css`, `index.html` — UI. `sw.js` + `manifest.webmanifest` — PWA.
- `server/server.js` — static files + WebSocket rooms (authoritative; clients only ever receive their own hand).

## Native app stores
The PWA is the mobile build. To ship to the App Store / Play Store, wrap `public/` with [Capacitor](https://capacitorjs.com) and point online play at the hosted server's WebSocket URL.

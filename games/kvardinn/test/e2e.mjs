// Plays a whole round end to end in Chromium against a running Worker: four phones and a big
// screen, with every WebSocket frame watched so that no device but the clue-giver's receives the
// target before the reveal. Also refreshes a phone mid-round and checks it gets its seat back.
//
//   npx wrangler dev --env standalone      (in another terminal), then
//   npm run test:e2e                       BASE_URL=http://localhost:8787/ by default
//   SHOTS=dir npm run test:e2e             also saves a screenshot of each step
import { mkdirSync } from "node:fs";
import { createRequire } from "node:module";

// Playwright isn't a dependency of the game: use whichever one is installed (npm i -g playwright).
const { chromium } = await import("playwright").catch(() => createRequire(import.meta.url)("playwright"));

const BASE = process.env.BASE_URL ?? "http://localhost:8787/";
const SHOTS = process.env.SHOTS;
if (SHOTS) mkdirSync(SHOTS, { recursive: true });
const fail = (m) => {
  console.error("FAIL:", m);
  process.exit(1);
};

const browser = await chromium.launch();
const phones = [];
let leak = null;
let revealed = false;

async function phone(name, opts = {}) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true, ...opts });
  const page = await ctx.newPage();
  const p = { name, page, pid: null, frames: [] };
  page.on("websocket", (ws) => {
    ws.on("framereceived", (f) => {
      let m;
      try {
        m = JSON.parse(String(f.payload));
      } catch {
        return;
      }
      if (m.t === "state") {
        p.view = m.view;
        const r = m.view.round;
        if (r && r.target !== null && !["reveal", "over"].includes(m.view.phase) && r.giver !== m.view.you) leak = `${name} received the target in phase ${m.view.phase}`;
      }
    });
  });
  page.on("pageerror", (e) => fail(`${name}: ${e.message}`));
  phones.push(p);
  return p;
}

const shot = async (p, label) => {
  if (SHOTS) await p.page.screenshot({ path: `${SHOTS}/${label}.png`, fullPage: true });
};
const until = async (fn, what, ms = 8000) => {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    if (await fn()) return;
    await new Promise((r) => setTimeout(r, 100));
  }
  fail(`timed out waiting for ${what}`);
};

// Host creates the room.
const anna = await phone("Anna");
await anna.page.goto(BASE);
await shot(anna, "01-home");
await anna.page.getByRole("button", { name: "Stofna nýjan leik" }).click();
await anna.page.waitForURL(/#[A-Z]{4}$/);
const code = new URL(anna.page.url()).hash.slice(1);
console.log("room", code);

async function join(p, team) {
  if (p.page.url() === "about:blank") await p.page.goto(`${BASE}#${code}`);
  await p.page.locator("#name-in").fill(p.name);
  await p.page.locator(`.teamopt.t${team}`).click();
  await p.page.getByRole("button", { name: "Ganga í leikinn" }).click();
  await until(() => p.view?.you, `${p.name} to join`);
}
await join(anna, 0);
const bjarni = await phone("Bjarni");
const dora = await phone("Dóra");
const einar = await phone("Einar");
await join(bjarni, 0);
await shot(bjarni, "02-join-form");
await join(dora, 1);
await join(einar, 1);

const tv = await phone("TV", { viewport: { width: 1280, height: 720 }, hasTouch: false });
await tv.page.goto(`${BASE}#${code}/skjar`);
await until(() => tv.view?.players?.length === 4, "the big screen to see four players");
await shot(anna, "03-lobby-host");
await shot(bjarni, "04-lobby-player");
await shot(tv, "05-tv-lobby");

// Custom scale, then start.
await anna.page.locator("#custom-box summary").click();
await anna.page.locator("#card-left").fill("Leiðinlegt partý");
await anna.page.locator("#card-right").fill("Frábært partý");
await anna.page.getByRole("button", { name: "Bæta við" }).click();
await until(() => anna.view?.customs?.length === 1, "the custom card");
await anna.page.getByRole("button", { name: /Hefja leik/ }).click();
await until(() => phones.every((p) => p.view?.phase === "clue"), "everyone to reach the clue phase");

const byId = (id) => phones.find((p) => p.view?.you === id);
const r0 = anna.view.round;
const giver = byId(r0.giver);
const guessers = phones.filter((p) => p !== tv && p !== giver && p.view.players.find((x) => x.id === p.view.you).team === r0.team);
const others = phones.filter((p) => p !== tv && p !== giver && !guessers.includes(p));
console.log("giver", giver.name, "guessers", guessers.map((p) => p.name), "others", others.map((p) => p.name));
if (!(await giver.page.locator(".bands:not([hidden])").count())) fail("the giver sees no target bands");
for (const p of [...guessers, ...others, tv]) if (await p.page.locator(".bands:not([hidden])").count()) fail(`${p.name} sees the bands`);
await shot(giver, "06-clue-giver");
await shot(guessers[0], "07-clue-waiting");

// A refresh mid-round keeps the seat.
const before = others[0].view.you;
await others[0].page.reload();
await until(() => others[0].view?.you === before && others[0].view.phase === "clue", "the refreshed phone to get its seat back");
console.log("reconnect ok:", others[0].name);

await giver.page.locator("#clue-in").fill("Nýbakaðar kleinur");
await giver.page.getByRole("button", { name: /Vísbending tilbúin/ }).click();
await until(() => phones.every((p) => p.view?.phase === "guess"), "the guess phase");
const g = guessers[0];
const track = g.page.locator(".track");
const box = await track.boundingBox();
const aimAt = r0.target !== null ? r0.target : 30;
await g.page.mouse.move(box.x + box.width * 0.5, box.y + box.height / 2);
await g.page.mouse.down();
await g.page.mouse.move(box.x + box.width * 0.3, box.y + box.height / 2, { steps: 8 });
await g.page.mouse.move(box.x + box.width * (giver.view.round.target / 100), box.y + box.height / 2, { steps: 8 });
await g.page.mouse.up();
await until(async () => {
  const left = await tv.page.locator(".needle").evaluate((el) => parseFloat(el.style.left));
  return Math.abs(left - giver.view.round.target) < 2;
}, "the big screen's pointer to follow the drag");
console.log("live pointer ok, aimed at", aimAt);
await shot(g, "08-guess-team");
await shot(others[0], "09-guess-other-team");
await shot(tv, "10-tv-guess");

const lockerP = byId(g.view.round.locker);
await lockerP.page.getByRole("button", { name: /Læsa ágiskun/ }).click();
await until(() => phones.every((p) => p.view?.phase === "bonus"), "the bonus phase");
await others[0].page.getByRole("button", { name: /Vinstra megin/ }).click();
await until(() => others[1].view?.round?.bonusPick === "L", "the bonus pick to sync");
await shot(others[1], "11-bonus");
const bl = byId(others[0].view.round.bonusLocker);
await bl.page.getByRole("button", { name: "Staðfesta val" }).click();
await until(() => phones.every((p) => p.view?.phase === "reveal"), "the reveal");
revealed = true;
await new Promise((r) => setTimeout(r, 2600));
await shot(g, "12-reveal");
await shot(tv, "13-tv-reveal");
const res = anna.view.round.result;
console.log("points", res.points, "bonus ok", res.bonusOk, "scores", anna.view.scores);
if (res.points < 3) fail(`aimed at the target but scored ${res.points}`);

await dora.page.getByRole("button", { name: /Næsta umferð/ }).click();
await until(() => phones.every((p) => p.view?.phase === "clue" && p.view.round.n === 2), "round two");
if (anna.view.round.team === r0.team) fail("the teams did not alternate");
await shot(tv, "14-tv-round2");

if (leak) fail(leak);
console.log("no target leaked before the reveal");
await browser.close();
console.log("E2E OK", revealed ? "" : "(no reveal?)");

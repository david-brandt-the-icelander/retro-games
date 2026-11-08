// Pixel Gambit: the page. A small hash router shows one screen at a time:
//
//   #/            the title screen: choose how to play
//   #/computer    choose Stockfish's strength and your colour
//   #/vs-computer the game against the computer (kept in this browser, so it survives a reload)
//   #/local       two players on one device
//   #/online      the lobby: challenge a friend by email, answer challenges, games in play, contacts
//   #/game/ID     an online game
//   #/history     finished games;  #/replay/ID  one of them, move by move
//
// A challenge link from an email (?challenge=ID) opens the lobby with that challenge on top.
import { api, ApiError } from "./api";
import { computerGame, loadComputer, localGame, localHistory, onlineGame, preloadEngine, replayGame, type Cleanup } from "./modes";
import { cleanEmail, LEVELS, type Challenge, type Contact, type GameView, type Lobby, type Me } from "./shared/protocol";
import { describe, scoreFor, sideToMove, type Side } from "./shared/rules";
import { isMuted, setMuted, sounds } from "./sound";
import { sprite } from "./sprites";
import { clear, copy, h, pieceIcon, put, toast, when } from "./ui";

const app = document.getElementById("app")!;
const userSlot = document.getElementById("user")!;
let me: Me = { user: null, providers: [] };
let cleanup: Cleanup | null = null;
let pendingChallenge: string | null = new URLSearchParams(location.search).get("challenge");
if (pendingChallenge && !/^[a-z0-9]{8,40}$/.test(pendingChallenge)) pendingChallenge = null;

const go = (hash: string) => { if (location.hash === hash) route(); else location.hash = hash; };

// ── Header ──

function renderUser(): void {
  clear(userSlot);
  const sound = h("button", { class: "icon-btn", title: "Sound on/off", "aria-label": "Sound on or off", "aria-pressed": String(!isMuted()) }, isMuted() ? "♪̸" : "♪");
  sound.addEventListener("click", () => { setMuted(!isMuted()); renderUser(); if (!isMuted()) sounds.select(); });
  if (me.user) {
    const menu = h("details", { class: "menu" },
      h("summary", null, h("span", { class: "avatar" }, me.user.name.slice(0, 1).toUpperCase()), h("span", { class: "uname" }, me.user.name)),
      h("div", { class: "menu-body" },
        h("p", { class: "muted" }, me.user.email),
        h("button", { class: "btn small", onclick: rename }, "Change name"),
        h("button", { class: "btn small", onclick: async () => { await api.logout(); me.user = null; renderUser(); go("#/"); } }, "Sign out"),
      ),
    );
    userSlot.append(sound, menu);
  } else {
    userSlot.append(sound, h("button", { class: "btn small", onclick: () => go("#/online") }, "Sign in"));
  }
}

function rename(): void {
  const name = prompt("Your name, as friends will see it:", me.user?.name ?? "");
  if (!name) return;
  api.rename(name).then((r) => { me.user = r.user; renderUser(); toast("Name changed."); }).catch((e: ApiError) => toast(e.message, "error"));
}

// ── Screens ──

function title(): void {
  const knight = h("canvas", { class: "hero-knight", width: 16, height: 16, "aria-hidden": "true" });
  knight.getContext("2d")!.drawImage(sprite("n", "w"), 0, 0);
  const saved = loadComputer();
  const resume = saved && !saved.outcome && saved.moves.length > 0;
  app.append(h("section", { class: "title" },
    h("div", { class: "hero" }, knight,
      h("div", null, h("h1", { class: "logo" }, "PIXEL", h("br"), "GAMBIT"), h("p", { class: "tagline" }, "Chess, 8-bit style. Beat the machine, or a friend."))),
    h("div", { class: "modes" },
      h("button", { class: "mode", onclick: () => go("#/computer") },
        pieceIcon("k", "b", 3), h("b", null, "VS COMPUTER"), h("span", null, "Stockfish at eight strengths, from beginner to merciless.")),
      h("button", { class: "mode", onclick: () => go("#/online") },
        pieceIcon("q", "w", 3), h("b", null, "VS A FRIEND"), h("span", null, "Challenge anyone by email. Play at your own pace, online.")),
      h("button", { class: "mode", onclick: () => go("#/local") },
        pieceIcon("n", "w", 3), h("b", null, "PASS & PLAY"), h("span", null, "Two players, one screen.")),
    ),
    resume ? h("p", { class: "resume" }, h("button", { class: "btn primary", onclick: () => go("#/vs-computer") }, `Continue your game vs Level ${saved!.level} →`)) : null,
  ));
}

function computerSetup(): void {
  preloadEngine();
  const prev = loadComputer();
  let level = prev?.level ?? 3;
  let color: Side | "random" = "random";
  const levels = h("div", { class: "levels", role: "radiogroup", "aria-label": "Strength" });
  const drawLevels = () => {
    put(levels, ...LEVELS.map((l, i) => h("button", {
      class: `level${level === i + 1 ? " on" : ""}`, role: "radio", "aria-checked": String(level === i + 1),
      onclick: () => { level = i + 1; drawLevels(); sounds.select(); },
    }, h("span", { class: "lv" }, `${i + 1}`), h("b", null, l.name), h("small", null, `${l.blurb} · ${l.elo}`))));
  };
  drawLevels();
  const colors = h("div", { class: "colors", role: "radiogroup", "aria-label": "Your colour" });
  const drawColors = () => {
    put(colors, ...(["white", "random", "black"] as const).map((c) => h("button", {
      class: `color${color === c ? " on" : ""}`, role: "radio", "aria-checked": String(color === c), onclick: () => { color = c; drawColors(); },
    }, c === "random" ? h("span", { class: "rand" }, "?") : pieceIcon("k", c === "white" ? "w" : "b", 2), c.toUpperCase())));
  };
  drawColors();
  app.append(h("section", { class: "card setup" },
    h("h2", null, "VS COMPUTER"),
    h("h3", null, "Strength"), levels,
    h("h3", null, "Play as"), colors,
    h("div", { class: "row" },
      h("button", { class: "btn", onclick: () => go("#/") }, "Back"),
      h("button", { class: "btn primary big", onclick: () => {
        const side: Side = color === "random" ? (Math.random() < 0.5 ? "white" : "black") : color;
        localStorage.setItem("chess.computer", JSON.stringify({ level, color: side, moves: [], outcome: null, saved: false }));
        go("#/vs-computer");
      } }, "START ▶")),
    h("p", { class: "muted fine" }, "The engine is Stockfish 19 (GPL-3.0), running in your browser."),
  ));
}

function vsComputer(): void {
  const save = loadComputer();
  if (!save) { go("#/computer"); return; }
  cleanup = computerGame(app, save, me, () => go("#/computer"));
}

function signIn(reason: string): void {
  const back = `${location.pathname}${location.search}${location.hash}`;
  const card = h("section", { class: "card signin" }, h("h2", null, "SIGN IN"), h("p", null, reason));
  const names: Record<string, string> = { google: "Google", github: "GitHub" };
  for (const p of me.providers.filter((p) => p !== "dev")) {
    card.append(h("a", { class: `btn big provider ${p}`, href: api.loginUrl(p, back) }, `Sign in with ${names[p] ?? p}`));
  }
  if (me.providers.includes("dev")) {
    const email = h("input", { type: "email", placeholder: "any@email.test", "aria-label": "Email for the development sign-in" });
    card.append(h("form", { class: "row", onsubmit: (e: Event) => {
      e.preventDefault();
      const em = cleanEmail(email.value);
      if (em) location.href = `${api.loginUrl("dev", back)}&email=${encodeURIComponent(em)}`;
    } }, email, h("button", { class: "btn" }, "Dev sign-in")));
  }
  if (!me.providers.length) card.append(h("p", { class: "muted" }, "Sign-in isn't set up on this server yet."));
  card.append(h("p", { class: "muted fine" }, "We keep your email address and name, so friends can challenge you, and your games. Nothing else."));
  app.append(card);
}

// ── The lobby ──

function lobby(): void {
  if (!me.user) { signIn("Sign in to challenge friends by email, keep your contacts and your game history."); return; }
  const root = h("section", { class: "lobby" });
  app.append(root);
  let data: Lobby | null = null;
  let timer: ReturnType<typeof setInterval> | null = null;
  let alive = true;

  const challengeCard = (prefill = ""): HTMLElement => {
    const email = h("input", { type: "email", required: true, placeholder: "friend@example.com", value: prefill, list: "contact-list", "aria-label": "Your friend's email address", autocomplete: "email" });
    const datalist = h("datalist", { id: "contact-list" }, ...(data?.contacts ?? []).map((c) => h("option", { value: c.email }, c.name ?? "")));
    let color: Side | "random" = "random";
    const colors = h("div", { class: "colors small", role: "radiogroup", "aria-label": "Your colour" });
    const drawColors = () => put(colors, ...(["white", "random", "black"] as const).map((c) => h("button", {
      type: "button", class: `color${color === c ? " on" : ""}`, role: "radio", "aria-checked": String(color === c), onclick: () => { color = c; drawColors(); },
    }, c === "random" ? h("span", { class: "rand" }, "?") : pieceIcon("k", c === "white" ? "w" : "b", 1), c)));
    drawColors();
    const result = h("div", { class: "sent" });
    const form = h("form", { class: "challenge-form", onsubmit: (e: Event) => {
      e.preventDefault();
      const em = cleanEmail(email.value);
      if (!em) { toast("That doesn't look like an email address.", "error"); return; }
      const btn = form.querySelector("button[type=submit]") as HTMLButtonElement;
      btn.disabled = true;
      api.challenge(em, color).then((r) => {
        btn.disabled = false;
        email.value = "";
        sounds.notify();
        put(result, 
          h("p", null, r.emailed ? `Challenge emailed to ${em}. ` : `Challenge waiting for ${em}. `,
            r.emailed ? "You can also send them this link:" : "They'll see it when they sign in with that address. Send them this link:"),
          h("div", { class: "row" }, h("input", { readonly: true, value: r.link, "aria-label": "Challenge link" }),
            h("button", { type: "button", class: "btn small", onclick: async () => toast((await copy(r.link)) ? "Link copied." : "Select the link and copy it.") }, "Copy")),
        );
        refresh();
      }).catch((err: ApiError) => { btn.disabled = false; toast(err.message, "error"); });
    } }, h("div", { class: "row" }, email, datalist), h("span", { class: "label" }, "You play"), colors,
      h("button", { type: "submit", class: "btn primary" }, "Send challenge"));
    return h("div", { class: "card" }, h("h2", null, "CHALLENGE A FRIEND"), form, result);
  };

  const challengeRow = (c: Challenge, incoming: boolean) => h("li", { class: "item" },
    incoming ? pieceIcon("n", c.color === "white" ? "b" : c.color === "black" ? "w" : "w", 2) : null,
    h("div", { class: "grow" },
      h("b", null, incoming ? c.from.name : c.toEmail),
      h("small", null, incoming ? `${c.from.email} · you play ${c.color === "random" ? "a random colour" : c.color === "white" ? "black" : "white"} · ${when(c.created)}` : `sent ${when(c.created)}`)),
    incoming
      ? h("div", { class: "row" },
        h("button", { class: "btn small primary", onclick: () => answer(c.id, "accept") }, "Accept"),
        h("button", { class: "btn small", onclick: () => answer(c.id, "decline") }, "Decline"))
      : h("div", { class: "row" },
        h("button", { class: "btn small", onclick: async () => toast((await copy(`${location.origin}${location.pathname}?challenge=${c.id}`)) ? "Link copied." : "Couldn't copy.") }, "Copy link"),
        h("button", { class: "btn small", onclick: () => answer(c.id, "cancel") }, "Cancel")),
  );

  const answer = (id: string, what: "accept" | "decline" | "cancel") => {
    api.answer(id, what).then((r) => {
      if (what === "accept" && r.game) { sounds.notify(); go(`#/game/${r.game.id}`); } else refresh();
    }).catch((e: ApiError) => { toast(e.message, "error"); refresh(); });
  };

  const gameRow = (g: GameView) => {
    const side: Side = g.white.id === me.user!.id ? "white" : "black";
    const opp = side === "white" ? g.black : g.white;
    const mine = sideToMove(g.moves.length) === side;
    return h("li", { class: `item clickable${mine ? " hot" : ""}`, tabindex: 0, role: "link", onclick: () => go(`#/game/${g.id}`),
      onkeydown: (e: KeyboardEvent) => { if (e.key === "Enter") go(`#/game/${g.id}`); } },
      pieceIcon("k", side === "white" ? "w" : "b", 2),
      h("div", { class: "grow" }, h("b", null, `vs ${opp.name}`), h("small", null, `${g.moves.length} moves · ${when(g.updated)}${g.drawOffer && g.drawOffer !== side ? " · draw offered" : ""}`)),
      h("span", { class: `tag${mine ? " hot" : ""}` }, mine ? "YOUR MOVE" : "THEIR MOVE"));
  };

  const contactRow = (c: Contact) => h("li", { class: "item" },
    h("span", { class: "avatar" }, (c.name ?? c.email).slice(0, 1).toUpperCase()),
    h("div", { class: "grow" },
      h("b", null, c.name ?? c.email),
      h("small", null, `${c.name ? `${c.email} · ` : ""}${c.wins}W ${c.losses}L ${c.draws}D${c.joined ? "" : " · hasn't joined yet"}`)),
    h("button", { class: "btn small primary", onclick: () => { put(root.querySelector(".challenge-slot")!, challengeCard(c.email)); window.scrollTo({ top: 0, behavior: "smooth" }); } }, "Challenge"),
    h("button", { class: "icon-btn", title: `Remove ${c.email}`, "aria-label": `Remove ${c.email} from contacts`, onclick: () => {
      api.removeContact(c.email).then(() => refresh()).catch((e: ApiError) => toast(e.message, "error"));
    } }, "×"),
  );

  const addContactForm = () => {
    const email = h("input", { type: "email", placeholder: "email", "aria-label": "Contact's email" });
    const name = h("input", { type: "text", placeholder: "name (optional)", "aria-label": "Contact's name", maxlength: 40 });
    return h("form", { class: "row add-contact", onsubmit: (e: Event) => {
      e.preventDefault();
      const em = cleanEmail(email.value);
      if (!em) { toast("That doesn't look like an email address.", "error"); return; }
      api.addContact(em, name.value).then(() => { email.value = name.value = ""; refresh(); }).catch((err: ApiError) => toast(err.message, "error"));
    } }, email, name, h("button", { class: "btn small" }, "Add"));
  };

  const draw = () => {
    if (!data) return;
    const slot = root.querySelector(".challenge-slot") ?? h("div", { class: "challenge-slot" }, challengeCard());
    const pending = pendingChallenge ? data.incoming.find((c) => c.id === pendingChallenge) : null;
    put(root, 
      pending ? h("div", { class: "card spotlight" }, h("h2", null, "A CHALLENGER APPEARS!"), h("ul", { class: "list" }, challengeRow(pending, true))) : null,
      h("div", { class: "cols" },
        h("div", null,
          slot,
          data.incoming.length ? h("div", { class: "card" }, h("h2", null, "CHALLENGES FOR YOU"), h("ul", { class: "list" }, ...data.incoming.map((c) => challengeRow(c, true)))) : null,
          h("div", { class: "card" }, h("h2", null, "GAMES IN PLAY"),
            data.active.length ? h("ul", { class: "list" }, ...data.active.map(gameRow)) : h("p", { class: "muted" }, "No games yet. Challenge someone!")),
          data.outgoing.length ? h("div", { class: "card" }, h("h2", null, "WAITING FOR AN ANSWER"), h("ul", { class: "list" }, ...data.outgoing.map((c) => challengeRow(c, false)))) : null,
        ),
        h("div", null,
          h("div", { class: "card" }, h("h2", null, "CONTACTS"),
            data.contacts.length ? h("ul", { class: "list" }, ...data.contacts.map(contactRow)) : h("p", { class: "muted" }, "Everyone you challenge, or who challenges you, is kept here."),
            addContactForm()),
          h("p", { class: "center" }, h("button", { class: "btn", onclick: () => go("#/history") }, "Game history →")),
        ),
      ),
    );
    const yourMove = data.active.filter((g) => sideToMove(g.moves.length) === (g.white.id === me.user!.id ? "white" : "black")).length;
    document.title = `${yourMove + data.incoming.length ? `(${yourMove + data.incoming.length}) ` : ""}Pixel Gambit`;
  };

  const refresh = () => api.lobby().then((d) => {
    if (!alive) return;
    const before = data;
    data = d;
    if (pendingChallenge && !d.incoming.some((c) => c.id === pendingChallenge)) checkPending();
    if (before && d.incoming.length > before.incoming.length) sounds.notify();
    // Keep a half-typed challenge: redraw everything but the challenge form.
    const active = document.activeElement;
    if (active instanceof HTMLInputElement && root.contains(active) && before) return;
    draw();
  }).catch((e: ApiError) => { if (!data) put(root, h("p", { class: "loading" }, e.message)); });

  const checkPending = () => {
    const id = pendingChallenge!;
    pendingChallenge = null;
    api.getChallenge(id).then((r) => {
      if (r.challenge.status === "accepted" && r.challenge.gameId) go(`#/game/${r.challenge.gameId}`);
      else if (r.challenge.status !== "open") toast(`That challenge was ${r.challenge.status}.`);
    }).catch((e: ApiError) => toast(e.status === 403 ? `That challenge was sent to another address than ${me.user!.email}.` : e.message, "error"));
  };

  root.append(h("p", { class: "loading" }, "Loading…"));
  refresh();
  timer = setInterval(() => { if (!document.hidden) refresh(); }, 10000);
  cleanup = () => { alive = false; if (timer) clearInterval(timer); document.title = "Pixel Gambit"; };
}

// ── History ──

function historyScreen(): void {
  const root = h("section", { class: "card history" }, h("h2", null, "GAME HISTORY"));
  app.append(root);
  const list = h("ul", { class: "list" });
  root.append(list);
  const row = (g: GameView) => {
    const blackIsMe = g.kind === "computer" ? g.white.id === null && g.white.name.startsWith("Stockfish") : g.black.id === me.user?.id;
    const side: Side = blackIsMe ? "black" : "white";
    const opp = side === "white" ? g.black : g.white;
    const score = scoreFor(g.result, side);
    return h("li", { class: "item clickable", tabindex: 0, role: "link", onclick: () => go(`#/replay/${g.id}`),
      onkeydown: (e: KeyboardEvent) => { if (e.key === "Enter") go(`#/replay/${g.id}`); } },
      h("span", { class: `tag ${score}` }, score.toUpperCase()),
      h("div", { class: "grow" }, h("b", null, `vs ${opp.name}`),
        h("small", null, `${describe({ result: g.result, reason: g.reason }, g.white.name, g.black.name)} · ${Math.ceil(g.moves.length / 2)} moves · ${when(g.updated)}`)),
      pieceIcon("k", side === "white" ? "w" : "b", 1));
  };
  if (!me.user) {
    const local = localHistory();
    root.append(h("p", { class: "muted" }, "Games against the computer on this device. ", h("a", { href: "#/online" }, "Sign in"), " to keep your history everywhere, with games against friends."));
    if (local.length) list.append(...local.map(row)); else list.append(h("li", { class: "muted" }, "No finished games yet."));
    return;
  }
  const more = h("button", { class: "btn" }, "More");
  let oldest = 0;
  const load = () => api.history(oldest || undefined).then((r) => {
    if (!r.games.length && !oldest) list.append(h("li", { class: "muted" }, "No finished games yet."));
    list.append(...r.games.map(row));
    if (r.games.length) oldest = r.games[r.games.length - 1].updated;
    more.hidden = r.games.length < 30;
  }).catch((e: ApiError) => toast(e.message, "error"));
  more.addEventListener("click", load);
  root.append(h("p", { class: "center" }, more));
  more.hidden = true;
  load();
}

function replayScreen(id: string): void {
  if (id.startsWith("local-")) {
    const g = localHistory().find((x) => x.id === id);
    if (g) cleanup = replayGame(app, g, me); else go("#/history");
    return;
  }
  if (!me.user) { signIn("Sign in to see your games."); return; }
  const loading = h("p", { class: "loading" }, "Loading…");
  app.append(loading);
  let done: Cleanup | null = null;
  let gone = false;
  api.game(id).then((r) => { loading.remove(); if (!gone) done = replayGame(app, r.game, me); }).catch((e: ApiError) => { loading.textContent = e.message; });
  cleanup = () => { gone = true; done?.(); };
}

// ── Routing ──

function route(): void {
  cleanup?.();
  cleanup = null;
  clear(app);
  const hash = location.hash || "#/";
  if (hash === "#signin-failed") { toast("Sign-in didn't work. Try again?", "error"); history.replaceState(null, "", "#/online"); }
  const [, page, arg] = (location.hash || "#/").split("/");
  document.querySelectorAll("nav a").forEach((a) => a.classList.toggle("on", a.getAttribute("href") === `#/${page ?? ""}`));
  switch (page) {
    case "computer": computerSetup(); break;
    case "vs-computer": vsComputer(); break;
    case "local": cleanup = localGame(app); break;
    case "online": lobby(); break;
    case "game": if (me.user && arg) cleanup = onlineGame(app, arg, me, go); else signIn("Sign in to play this game."); break;
    case "history": historyScreen(); break;
    case "replay": replayScreen(arg ?? ""); break;
    default: title();
  }
  window.scrollTo(0, 0);
}

window.addEventListener("hashchange", route);

api.me().then((m) => { me = m; }).catch(() => { toast("The server can't be reached: only the computer and pass & play work.", "error"); })
  .finally(() => {
    renderUser();
    if (pendingChallenge) {
      // Show the lobby, which shows the challenge on top.
      // Signed out, keep it in the address, so signing in comes back to it.
      history.replaceState(null, "", `${location.pathname}${me.user ? "" : `?challenge=${pendingChallenge}`}#/online`);
    }
    route();
  });

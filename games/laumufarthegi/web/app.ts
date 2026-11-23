// Laumufarþegi in the browser: one page that draws the screen the room's view calls for. The room's Durable
// Object decides everything; this file only shows the view it is sent and passes on what the player taps.
import { CLUE_MAX, MIN_PLAYERS, NAME_MAX, type Action, type Settings, type View } from "../shared/game";
import { BASE, isCode, type ClientMessage, type CreatedRoom, type ServerMessage } from "../shared/protocol";

const HOW_TO = [
  "Allir sjá sama efnið og 16 orð. Eitt orðanna er leyniorðið.",
  "Allir nema einn sjá leyniorðið. Laumufarþeginn sér bara efnið.",
  "Hver á fætur öðrum gefur stutta vísbendingu um leyniorðið.",
  "Of augljós vísbending hjálpar laumufarþeganum; of óljós vekur grun.",
  "Svo kjósa allir þann sem þeir halda að sé laumufarþeginn.",
  "Náist hann má hann giska á orðið. Rétt gisk gefur honum 1 stig.",
  "Rétt atkvæði gefur 1 stig. Sleppi laumufarþeginn fær hann 3 stig.",
  "Giski hann rangt fá allir hinir 1 stig. Flest stig í lokin vinna!",
];

// ── Small DOM helpers (text always goes in as text, never as HTML) ──

type Kid = Node | string | number | null | undefined | false;
function h<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Record<string, unknown> | null = null, ...kids: Kid[]): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs ?? {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2), v as EventListener);
    else if (k === "class") el.className = String(v);
    else if (k === "value") (el as HTMLInputElement).value = String(v);
    else if (k === "checked") (el as HTMLInputElement).checked = !!v;
    else if (k === "disabled") (el as HTMLButtonElement).disabled = !!v;
    else el.setAttribute(k, v === true ? "" : String(v));
  }
  for (const kid of kids) if (kid !== null && kid !== undefined && kid !== false) el.append(kid instanceof Node ? kid : String(kid));
  return el;
}
const app = document.getElementById("app")!;
const store = {
  get(k: string): string | null { try { return localStorage.getItem(k); } catch { return null; } },
  set(k: string, v: string) { try { localStorage.setItem(k, v); } catch { /* private mode */ } },
  del(k: string) { try { localStorage.removeItem(k); } catch { /* private mode */ } },
};
const tokenKey = (code: string) => `laumufarthegi:${code}`;
const NAME_KEY = "laumufarthegi:name";

// ── Connection ──

let code: string | null = null;
let ws: WebSocket | null = null;
let current: View | null = null;
let clockOffset = 0;
let retry = 0;
let pingTimer = 0;
let removed = false;
let toast: { text: string; until: number } | null = null;
let pendingName: string | null = null;

function connect(): void {
  if (!code) return;
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  const sock = new WebSocket(`${proto}//${location.host}${BASE}/api/rooms/${code}/ws`);
  ws = sock;
  sock.onopen = () => {
    retry = 0;
    const token = store.get(tokenKey(code!));
    const msg: ClientMessage = token ? { t: "join", token } : { t: "join", name: pendingName ?? "" };
    if (!token && !pendingName) { sock.close(); return; }
    sock.send(JSON.stringify(msg));
    clearInterval(pingTimer);
    pingTimer = window.setInterval(() => { if (sock.readyState === WebSocket.OPEN) sock.send("ping"); }, 25_000);
  };
  sock.onmessage = (e) => {
    if (e.data === "pong") return;
    const msg = JSON.parse(e.data) as ServerMessage;
    if (msg.t === "welcome") { store.set(tokenKey(code!), msg.token); pendingName = null; }
    else if (msg.t === "state") { current = msg.view; clockOffset = msg.view.now - Date.now(); render(); }
    else if (msg.t === "error") {
      if (!current) { pendingName = null; store.del(tokenKey(code!)); }
      showToast(msg.message);
      if (!current) render();
    } else if (msg.t === "removed") { removed = true; store.del(tokenKey(code!)); render(); }
  };
  sock.onclose = (e) => {
    clearInterval(pingTimer);
    if (ws !== sock) return;
    ws = null;
    if (removed || e.code === 4403) return;
    if (e.code === 4404) { current = null; store.del(tokenKey(code!)); showToast("Þessi leikur er ekki lengur til."); render(); return; }
    if (!store.get(tokenKey(code!)) && !pendingName) { render(); return; }
    render();
    retry = Math.min(retry + 1, 6);
    setTimeout(connect, 500 * 2 ** retry);
  };
}

function send(a: Action): void {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(a));
  else showToast("Engin tenging í augnablikinu. Reyni aftur…");
}

function showToast(text: string): void {
  toast = { text, until: Date.now() + 4000 };
  renderToast();
  setTimeout(renderToast, 4100);
}
function renderToast(): void {
  document.getElementById("toast")?.remove();
  if (toast && Date.now() < toast.until) document.body.append(h("div", { id: "toast", role: "status" }, toast.text));
}

// ── Screens ──

function render(): void {
  const focus = document.activeElement as HTMLInputElement | null;
  const keep = focus && focus.id ? { id: focus.id, value: focus.value, pos: focus.selectionStart } : null;
  app.replaceChildren(screen());
  if (keep) {
    const el = document.getElementById(keep.id) as HTMLInputElement | null;
    if (el && el.tagName === "INPUT" && el.type === "text") { el.value = keep.value; el.focus(); if (keep.pos !== null) el.setSelectionRange(keep.pos, keep.pos); }
  }
  tickTimers();
}

function screen(): Node {
  if (removed) return page(h("h2", null, "Þú hefur verið fjarlægð(ur) úr leiknum."), h("a", { class: "btn", href: `${BASE}/` }, "Á forsíðu"));
  if (!code) return homeScreen();
  if (!current) {
    if (store.get(tokenKey(code)) || pendingName) return page(h("p", { class: "big center" }, "Tengist leik ", h("b", null, code), "…"));
    return joinScreen();
  }
  const v = current;
  switch (v.phase) {
    case "lobby": return lobbyScreen(v);
    case "clues": case "voting": case "guess": return roundScreen(v);
    case "reveal": return revealScreen(v);
    case "over": return overScreen(v);
  }
}

function page(...kids: Kid[]): HTMLElement {
  return h("main", null,
    h("header", null, h("a", { class: "brand", href: `${BASE}/` }, "Laumufarþegi"), current ? connectionBadge() : null),
    ...kids);
}

function connectionBadge(): Node {
  const on = !!ws && ws.readyState === WebSocket.OPEN;
  return h("span", { class: on ? "conn on" : "conn off" }, on ? `Leikur ${code}` : "Tengist aftur…");
}

function howTo(): Node {
  return h("details", { class: "howto", open: !current || current.phase === "lobby" ? true : undefined },
    h("summary", null, "Hvernig er spilað?"),
    h("ol", null, ...HOW_TO.map((line) => h("li", null, line))));
}

function homeScreen(): Node {
  const name = h("input", { id: "host-name", type: "text", maxlength: NAME_MAX, placeholder: "Nafnið þitt", value: store.get(NAME_KEY) ?? "", autocomplete: "nickname" });
  const joinCode = h("input", { id: "join-code", type: "text", maxlength: 5, placeholder: "ABCDE", autocapitalize: "characters", autocomplete: "off" });
  const status = h("p", { class: "muted" });
  const create = h("button", { class: "btn primary", onclick: async () => {
    const n = name.value.trim();
    if (!n) { showToast("Sláðu inn nafnið þitt."); name.focus(); return; }
    store.set(NAME_KEY, n);
    create.disabled = true;
    const r = await fetch(`${BASE}/api/rooms`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: n }) });
    const body = await r.json().catch(() => ({}));
    create.disabled = false;
    if (r.status === 401) { status.replaceChildren(String(body.error ?? ""), " ", h("a", { href: body.signIn }, "Skrá inn")); return; }
    if (!r.ok) { showToast(body.error ?? "Ekki tókst að stofna leik."); return; }
    const room = body as CreatedRoom;
    store.set(tokenKey(room.code), room.token);
    openRoom(room.code);
  } }, "Stofna nýjan leik");
  fetch(`${BASE}/api/me`).then((r) => r.json()).then((m: { canHost: boolean; name: string; signIn: string }) => {
    if (!m.canHost) status.replaceChildren("Til að stofna leik þarftu að ", h("a", { href: m.signIn }, "skrá þig inn"), ". Aðrir ganga í leikinn með hlekknum, án innskráningar.");
    else if (m.name && !name.value) name.value = m.name;
  }).catch(() => undefined);
  const goJoin = () => {
    const c = joinCode.value.trim().toUpperCase();
    if (!isCode(c)) { showToast("Leiknúmerið er fimm bókstafir."); return; }
    openRoom(c);
  };
  joinCode.addEventListener("keydown", (e) => { if (e.key === "Enter") goJoin(); });
  return page(
    h("p", { class: "lead" }, "Orðaleikur fyrir 3–10 manns þar sem einn veit ekki leyniorðið."),
    h("section", { class: "card" }, h("h2", null, "Stofna leik"), h("label", { for: "host-name" }, "Nafn"), name, create, status),
    h("section", { class: "card" }, h("h2", null, "Ganga í leik"), h("label", { for: "join-code" }, "Leiknúmer"), joinCode, h("button", { class: "btn", onclick: goJoin }, "Ganga í leik")),
    howTo(),
  );
}

function joinScreen(): Node {
  const name = h("input", { id: "join-name", type: "text", maxlength: NAME_MAX, placeholder: "Nafnið þitt", value: store.get(NAME_KEY) ?? "", autocomplete: "nickname" });
  const go = () => {
    const n = name.value.trim();
    if (!n) { showToast("Sláðu inn nafnið þitt."); return; }
    store.set(NAME_KEY, n);
    pendingName = n;
    render();
    connect();
  };
  name.addEventListener("keydown", (e) => { if (e.key === "Enter") go(); });
  return page(
    h("section", { class: "card" },
      h("h2", null, "Ganga í leik ", h("span", { class: "code" }, code!)),
      h("label", { for: "join-name" }, "Hvað heitir þú?"), name,
      h("button", { class: "btn primary", onclick: go }, "Ganga í leikinn")),
    howTo(),
  );
}

function lobbyScreen(v: View): Node {
  const link = `${location.origin}${BASE}/?r=${v.code}`;
  const connected = v.players.filter((p) => p.connected).length;
  return page(
    h("section", { class: "card center" },
      h("p", { class: "muted" }, "Leiknúmer"),
      h("div", { class: "code huge" }, v.code),
      h("p", null, "Sendu hlekkinn á hina, t.d. í Teams:"),
      h("div", { class: "share" },
        h("input", { id: "share-link", type: "url", readonly: true, value: link, onfocus: (e: Event) => (e.target as HTMLInputElement).select() }),
        h("button", { class: "btn", onclick: () => copy(link) }, "Afrita hlekk"))),
    playersCard(v, true),
    settingsCard(v),
    v.me.host
      ? h("button", { class: "btn primary wide", disabled: connected < MIN_PLAYERS, onclick: () => send({ t: "start" }) },
          connected < MIN_PLAYERS ? `Bíð eftir leikmönnum (${connected}/${MIN_PLAYERS})` : "Byrja leikinn")
      : h("p", { class: "center big" }, "Bíð eftir að stjórnandinn byrji…"),
    claimHost(v),
    howTo(),
  );
}

function playersCard(v: View, kick: boolean): Node {
  const sorted = v.phase === "lobby" ? v.players : [...v.players].sort((a, b) => b.score - a.score);
  return h("section", { class: "card" },
    h("h2", null, `Leikmenn (${v.players.length})`),
    h("ul", { class: "players" }, ...sorted.map((p) => h("li", { class: p.connected ? "" : "away" },
      h("span", { class: "dot" }), h("span", { class: "pname" }, p.name, p.id === v.me.id ? " (þú)" : ""),
      p.host ? h("span", { class: "tag" }, "stjórnandi") : null,
      v.phase !== "lobby" ? h("span", { class: "score" }, `${p.score} stig`) : null,
      kick && v.me.host && p.id !== v.me.id ? h("button", { class: "x", title: `Fjarlægja ${p.name}`, onclick: () => { if (confirm(`Fjarlægja ${p.name} úr leiknum?`)) send({ t: "kick", player: p.id }); } }, "✕") : null))));
}

function settingsCard(v: View): Node {
  const s = v.settings;
  const DIFF = ["", "Aðeins létt efni", "Létt og miðlungs", "Öll efni, líka erfið"];
  if (!v.me.host) {
    return h("section", { class: "card" }, h("h2", null, "Stillingar"),
      h("p", null, `${s.rounds} umferðir · ${s.clueSeconds} sek. á vísbendingu · ${s.voteSeconds} sek. að kjósa · ${DIFF[s.maxDifficulty]}${s.childOnly ? " · barnvænt" : ""}`));
  }
  const set = (patch: Partial<Settings>) => send({ t: "settings", settings: patch });
  const num = (id: string, label: string, value: number, min: number, max: number, step: number, key: keyof Settings) =>
    h("label", { class: "row", for: id }, h("span", null, label),
      h("input", { id, type: "number", inputmode: "numeric", min, max, step, value, onchange: (e: Event) => set({ [key]: Number((e.target as HTMLInputElement).value) } as Partial<Settings>) }));
  return h("section", { class: "card" }, h("h2", null, "Stillingar"),
    num("set-rounds", "Fjöldi umferða", s.rounds, 1, 20, 1, "rounds"),
    num("set-clue", "Sekúndur á vísbendingu", s.clueSeconds, 15, 180, 5, "clueSeconds"),
    num("set-vote", "Sekúndur til að kjósa", s.voteSeconds, 20, 300, 10, "voteSeconds"),
    h("label", { class: "row", for: "set-diff" }, h("span", null, "Efni"),
      h("select", { id: "set-diff", onchange: (e: Event) => set({ maxDifficulty: Number((e.target as HTMLSelectElement).value) }) },
        ...[1, 2, 3].map((d) => h("option", { value: d, selected: d === s.maxDifficulty ? true : undefined }, DIFF[d])))),
    h("label", { class: "row check", for: "set-child" }, h("span", null, "Aðeins barnvæn efni"),
      h("input", { id: "set-child", type: "checkbox", checked: s.childOnly, onchange: (e: Event) => set({ childOnly: (e.target as HTMLInputElement).checked }) })),
    h("button", { class: "btn small", onclick: () => send({ t: "resetTopics" }) }, "Nota öll efni aftur"));
}

const nameOf = (v: View, id: string | null) => (id ? v.players.find((p) => p.id === id)?.name ?? "?" : "?");

function roundScreen(v: View): Node {
  const r = v.round!;
  const myTurn = v.phase === "clues" && r.order[r.turn] === v.me.id;
  const head = h("section", { class: "card" },
    h("div", { class: "roundline" }, h("span", null, `Umferð ${r.number} af ${v.settings.rounds}`), timer(r.deadline)),
    h("h2", { class: "topic" }, r.topic.efni),
    roleBanner(v));
  const grid = h("div", { class: "grid" + (v.phase === "guess" && v.me.stowaway ? " pick" : "") },
    ...r.topic.ord.map((w, i) => {
      const cls = ["cell", r.secret === i ? "secret" : ""].join(" ");
      if (v.phase === "guess" && v.me.stowaway) return h("button", { class: cls, onclick: () => { if (confirm(`Giska á „${w}“?`)) send({ t: "guess", index: i }); } }, w);
      return h("div", { class: cls }, w);
    }));
  const parts: Kid[] = [head, grid, cluesCard(v)];
  if (v.phase === "clues") {
    if (myTurn) {
      const input = h("input", { id: "clue", type: "text", maxlength: CLUE_MAX, placeholder: "Ein stutt vísbending", autocomplete: "off", enterkeyhint: "send" });
      const go = () => { const t = input.value.trim(); if (t) send({ t: "clue", text: t }); };
      input.addEventListener("keydown", (e) => { if (e.key === "Enter") go(); });
      parts.splice(1, 0, h("section", { class: "card yourturn" }, h("h2", null, "Komið að þér!"), input, h("button", { class: "btn primary wide", onclick: go }, "Senda vísbendingu")));
      setTimeout(() => document.getElementById("clue")?.focus(), 0);
    } else if (v.me.inRound) {
      parts.splice(1, 0, h("p", { class: "big center" }, "Komið að ", h("b", null, nameOf(v, r.order[r.turn])), "…"));
    }
  }
  if (v.phase === "voting") parts.splice(1, 0, voteCard(v));
  if (v.phase === "guess") {
    parts.splice(1, 0, v.me.stowaway
      ? h("section", { class: "card alert" }, h("h2", null, "Þú náðist!"), h("p", null, "Giskaðu á leyniorðið: smelltu á orð í töflunni."))
      : h("section", { class: "card" }, h("p", { class: "big center" }, h("b", null, nameOf(v, r.accused)), " er laumufarþeginn og giskar nú á leyniorðið…")));
  }
  parts.push(playersCard(v, false), hostBar(v), claimHost(v));
  return page(...parts);
}

function roleBanner(v: View): Node {
  const r = v.round!;
  if (!v.me.inRound) return h("p", { class: "banner neutral" }, "Þú kemst inn í næstu umferð. Fylgstu með!");
  if (v.me.stowaway) return h("p", { class: "banner stow" }, "🕵️ Þú ert laumufarþeginn! Þú veist ekki orðið. Reyndu að falla inn í hópinn.");
  return h("p", { class: "banner word" }, "Leyniorðið er ", h("b", null, r.topic.ord[r.secret ?? 0]));
}

function cluesCard(v: View): Node {
  const r = v.round!;
  return h("section", { class: "card" }, h("h2", null, "Vísbendingar"),
    h("ol", { class: "clues" }, ...r.order.map((id, i) => {
      const c = r.clues[i];
      const now = v.phase === "clues" && i === r.turn;
      return h("li", { class: now ? "now" : "" }, h("span", { class: "who" }, nameOf(v, id)),
        h("span", { class: "what" }, c ? c.text : now ? "skrifar…" : ""));
    })));
}

function voteCard(v: View): Node {
  const r = v.round!;
  if (!v.me.inRound) return h("p", { class: "big center" }, "Leikmennirnir kjósa…");
  const voted = v.players.filter((p) => p.voted).length;
  return h("section", { class: "card vote" },
    h("h2", null, "Hver er laumufarþeginn?"),
    h("p", { class: "muted" }, `${voted} af ${r.order.length} hafa kosið. Þú getur skipt um skoðun þar til allir hafa kosið.`),
    h("div", { class: "choices" }, ...r.order.filter((id) => id !== v.me.id).map((id) => {
      const clue = r.clues[r.order.indexOf(id)]?.text ?? "";
      return h("button", { class: "choice" + (r.myVote === id ? " chosen" : ""), onclick: () => send({ t: "vote", target: id }) },
        h("b", null, nameOf(v, id)), h("span", null, `„${clue}“`));
    })));
}

function revealScreen(v: View): Node {
  const r = v.round!;
  const x = r.reveal!;
  const stow = nameOf(v, x.stowaway);
  const word = r.topic.ord[x.secret];
  let verdict: string;
  if (x.accused !== x.stowaway) verdict = x.accused ? `Þið kusuð ${nameOf(v, x.accused)} út, en laumufarþeginn slapp!` : "Atkvæðin féllu jöfn og laumufarþeginn slapp!";
  else if (x.guess === x.secret) verdict = `${stow} náðist, en giskaði rétt á orðið!`;
  else verdict = `${stow} náðist og ${x.guess !== null && x.guess >= 0 ? `giskaði á „${r.topic.ord[x.guess]}“` : "giskaði ekki"}.`;
  const last = v.roundsPlayed >= v.settings.rounds;
  return page(
    h("section", { class: "card reveal center" },
      h("p", { class: "muted" }, `Umferð ${r.number} af ${v.settings.rounds} · ${r.topic.efni}`),
      h("p", null, "Laumufarþeginn var"), h("div", { class: "huge" }, stow),
      h("p", null, "Leyniorðið var ", h("b", null, word)),
      h("p", { class: "big" }, verdict)),
    h("section", { class: "card" }, h("h2", null, "Atkvæði og stig í umferðinni"),
      h("ul", { class: "votes" }, ...r.order.map((id) => h("li", null,
        h("span", null, nameOf(v, id), x.votes[id] ? ` → ${nameOf(v, x.votes[id])}` : " (kaus ekki)"),
        h("span", { class: "score" }, `+${x.points[id] ?? 0}`))))),
    playersCard(v, true),
    v.me.host ? h("button", { class: "btn primary wide", onclick: () => send({ t: "next" }) }, last ? "Sjá lokastöðu" : "Næsta umferð")
      : h("p", { class: "center" }, "Bíð eftir stjórnandanum…"),
    claimHost(v),
  );
}

function overScreen(v: View): Node {
  const ranked = [...v.players].sort((a, b) => b.score - a.score);
  const top = ranked[0]?.score ?? 0;
  const winners = ranked.filter((p) => p.score === top).map((p) => p.name);
  return page(
    h("section", { class: "card center" }, h("h2", null, "Leik lokið!"),
      h("p", { class: "huge" }, "🏆 ", winners.join(" og ")),
      h("ol", { class: "final" }, ...ranked.map((p) => h("li", null, h("span", null, p.name), h("span", { class: "score" }, `${p.score} stig`))))),
    settingsCard(v),
    v.me.host ? h("button", { class: "btn primary wide", onclick: () => send({ t: "start" }) }, "Nýr leikur með sömu leikmönnum")
      : h("p", { class: "center" }, "Stjórnandinn getur byrjað nýjan leik."),
    claimHost(v),
  );
}

function hostBar(v: View): Node | null {
  if (!v.me.host) return null;
  return h("p", { class: "center" }, h("button", { class: "btn small ghost", onclick: () => { if (confirm("Ljúka leiknum núna?")) send({ t: "end" }); } }, "Ljúka leik"));
}

function claimHost(v: View): Node | null {
  if (!v.canClaimHost) return null;
  return h("p", { class: "center" }, "Stjórnandinn er ekki tengdur. ",
    h("button", { class: "btn small", onclick: () => send({ t: "claimHost" }) }, "Taka við stjórninni"));
}

// ── Timers ──

function timer(deadline: number | null): Node | null {
  if (!deadline) return null;
  return h("span", { class: "timer", "data-deadline": deadline });
}
function tickTimers(): void {
  for (const el of document.querySelectorAll<HTMLElement>(".timer")) {
    const left = Math.max(0, Math.ceil((Number(el.dataset.deadline) - (Date.now() + clockOffset)) / 1000));
    el.textContent = `⏱ ${left} s`;
    el.classList.toggle("low", left <= 10);
  }
}
setInterval(tickTimers, 250);

async function copy(text: string): Promise<void> {
  try { await navigator.clipboard.writeText(text); showToast("Hlekkurinn er afritaður. Límdu hann í Teams!"); }
  catch { (document.getElementById("share-link") as HTMLInputElement | null)?.select(); showToast("Afritaðu hlekkinn úr reitnum."); }
}

function openRoom(c: string): void {
  code = c;
  history.replaceState(null, "", `${BASE}/?r=${c}`);
  current = null;
  render();
  if (store.get(tokenKey(c))) connect();
}

// ── Start ──
const param = new URLSearchParams(location.search).get("r")?.toUpperCase() ?? null;
if (param && isCode(param)) openRoom(param);
else render();

// Kvarðinn's page: every screen, for players on their phones and for the room's big screen.
//
//   (no hash)       the front page: start a game or type a code
//   #ABCD           room ABCD: join, the lobby and the game
//   #ABCD/skjar     room ABCD on a TV or projector: everything but the hidden target
//
// The server sends a View after every change; render() redraws the screen from it. The scale
// (scale.ts) is one element moved into each new screen, so dragging is never interrupted, and a
// redraw that arrives mid-drag waits until the drag ends.
import qrcode from "qrcode-generator";
import { GOALS, MAX_CLUE, MAX_END, MAX_NAME, ROUND_COUNTS, TEAM_NAMES, type Action, type PlayerView, type TeamId, type View } from "../engine/game";
import { Connection, loadSeat, saveSeat, type ServerMessage } from "./net";
import { Scale } from "./scale";
import { playPoints, playTick, setSound, soundOn, unlockAudio } from "./sound";
import { GAME_NAME, esc, howTo, stig } from "./text";
import { bindTour, tourHtml } from "./tour";

const app = document.getElementById("app")!;
const toastEl = document.getElementById("toast")!;

interface Route { code: string; screen: boolean }

let route: Route | null = null;
let conn: Connection | null = null;
let view: View | null = null;
let connected = false;
let gone = false;
let welcomed = false;
let pendingRender = false;
/** The round whose reveal this device has already animated. */
let revealedRound = -1;
let lastPhaseKey = "";
let busy = false;
/** Which fold-out sections (details[id]) are open, so a redraw keeps them as the player left them. */
const openDetails = new Set<string>();
const openAttr = (id: string): string => (openDetails.has(id) ? "open" : "");

const scale = new Scale(
  (v) => sendAct({ a: "move", value: v }),
  () => {
    if (pendingRender) render();
  },
);

function parseRoute(): Route | null {
  const h = decodeURIComponent(location.hash.replace(/^#/, "")).trim();
  const m = h.match(/^([A-Za-z]{4})(\/skjar)?$/);
  return m ? { code: m[1].toUpperCase(), screen: !!m[2] } : null;
}

function shareLink(code: string): string {
  return `${location.origin}${location.pathname}#${code}`;
}

function toast(msg: string): void {
  toastEl.textContent = msg;
  toastEl.hidden = false;
  toastEl.classList.remove("show");
  void toastEl.offsetWidth;
  toastEl.classList.add("show");
  clearTimeout((toast as unknown as { t?: number }).t);
  (toast as unknown as { t?: number }).t = window.setTimeout(() => (toastEl.hidden = true), 4500);
}

function sendAct(action: Action): void {
  if (!conn?.send({ t: "act", action })) toast("Ekkert samband. Reyni aftur…");
}

// ---------- connection ----------

function enterRoute(): void {
  const next = parseRoute();
  // Setting location.hash fires both popstate and hashchange: act on the first only.
  if (conn && route && next && next.code === route.code && next.screen === route.screen) return;
  conn?.stop();
  conn = null;
  view = null;
  gone = false;
  welcomed = false;
  connected = false;
  revealedRound = -1;
  route = parseRoute();
  if (route) {
    conn = new Connection(route.code, route.screen, onMessage, (c) => {
      connected = c;
      render();
    });
    conn.open();
  }
  document.body.classList.toggle("bigscreen", !!route?.screen);
  render();
}

function onMessage(m: ServerMessage): void {
  if (!route) return;
  switch (m.t) {
    case "welcome":
      welcomed = true;
      if (!m.you && loadSeat(route.code)) saveSeat(route.code, null);
      return;
    case "seat":
      saveSeat(route.code, { pid: m.pid, token: m.token });
      return;
    case "state":
      view = m.view;
      welcomed = true;
      render();
      return;
    case "pointer":
      if (view?.round) view.round.pointer = m.value;
      if (m.by !== view?.you) scale.remotePointer(m.value);
      return;
    case "error":
      busy = false;
      toast(m.message);
      return;
    case "removed":
      saveSeat(route.code, null);
      toast("Gestgjafinn tók þig úr leiknum.");
      return;
    case "gone":
      gone = true;
      render();
      return;
    case "pong":
      return;
  }
}

// ---------- helpers ----------

const player = (id: string | null | undefined): PlayerView | undefined => view?.players.find((p) => p.id === id);
const nameOf = (id: string | null | undefined): string => esc(player(id)?.name ?? "?");
const teamName = (t: TeamId): string => TEAM_NAMES[t];
const me = (): PlayerView | undefined => player(view?.you);
const amHost = (): boolean => !!view && !!view.you && view.host === view.you;
const coop = (): boolean => view?.settings.mode === "coop";

function teamChip(t: TeamId): string {
  return `<span class="chip t${t}">${teamName(t)}</span>`;
}

function personLabel(p: PlayerView, opts: { you?: boolean } = {}): string {
  const bits = [esc(p.name)];
  if (opts.you) bits.push(`<span class="tag">þú</span>`);
  if (view?.host === p.id) bits.push(`<span class="tag host">gestgjafi</span>`);
  return `<span class="person ${p.online ? "" : "offline"}"><span class="dot" title="${p.online ? "Tengd(ur)" : "Ekki tengd(ur)"}"></span>${bits.join(" ")}</span>`;
}

function qrSvg(text: string): string {
  const qr = qrcode(0, "M");
  qr.addData(text);
  qr.make();
  return qr.createSvgTag({ cellSize: 6, margin: 2, scalable: true });
}

/** Keeps what a player is typing, and where, across a redraw. */
function keepInputs<T>(draw: () => T): T {
  const vals = new Map<string, string>();
  app.querySelectorAll<HTMLInputElement>("input[id]").forEach((i) => vals.set(i.id, i.type === "checkbox" ? "" : i.value));
  const active = document.activeElement as HTMLInputElement | null;
  const focusId = active && active.id && active.tagName === "INPUT" ? active.id : null;
  const sel = focusId ? [active!.selectionStart, active!.selectionEnd] : null;
  const out = draw();
  vals.forEach((v, id) => {
    const el = document.getElementById(id) as HTMLInputElement | null;
    if (el && el.type !== "checkbox" && v && !el.dataset.fresh) el.value = v;
  });
  if (focusId) {
    const el = document.getElementById(focusId) as HTMLInputElement | null;
    if (el) {
      el.focus();
      try {
        if (sel) el.setSelectionRange(sel[0], sel[1]);
      } catch {
        /* not a text field */
      }
    }
  }
  return out;
}

// ---------- screens ----------

function render(): void {
  if (scale.dragging) {
    pendingRender = true;
    return;
  }
  pendingRender = false;
  keepInputs(() => {
    app.innerHTML = screenHtml();
    const slot = document.getElementById("scale-slot");
    if (slot && view?.round) {
      slot.replaceWith(scale.el);
      updateScale();
    }
  });
  const key = `${view?.phase}:${view?.round?.n}`;
  if (key !== lastPhaseKey) {
    if (lastPhaseKey && view && view.phase !== "lobby") playTick();
    lastPhaseKey = key;
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}

function updateScale(): void {
  const v = view!;
  const r = v.round!;
  const revealed = v.phase === "reveal" || v.phase === "over";
  const doReveal = v.phase === "reveal" && revealedRound !== r.n;
  if (doReveal) {
    revealedRound = r.n;
    const pts = r.result?.points ?? 0;
    setTimeout(() => playPoints(pts), 1300);
    if (pts > 0 && "vibrate" in navigator) setTimeout(() => navigator.vibrate?.(60 * pts), 1300);
  }
  scale.update({
    left: r.card[0],
    right: r.card[1],
    pointer: r.pointer,
    target: r.target,
    movable: canMoveHere(),
    tone: r.team === null ? "coop" : `t${r.team}`,
    reveal: doReveal,
    points: revealed ? (r.result?.points ?? null) : null,
  });
}

function canMoveHere(): boolean {
  const v = view;
  const r = v?.round;
  const m = me();
  if (!v || !r || !m || route?.screen || v.phase !== "guess" || r.giver === m.id) return false;
  return r.team === null || m.team === r.team;
}

function screenHtml(): string {
  if (!route) return homeHtml();
  if (gone) return goneHtml();
  if (!view || !welcomed) return `<div class="center"><p class="loading">${connected ? "Sæki leikinn…" : "Tengist…"}</p></div>`;
  const top = topBar();
  if (route.screen) return top + bigScreenHtml();
  if (!view.you) return top + joinHtml();
  if (view.phase === "lobby") return top + lobbyHtml();
  return top + gameHtml();
}

function topBar(): string {
  const code = route!.code;
  return `<header class="topbar">
    <a class="brand" href="${location.pathname}" data-home>${logo()}<span>${GAME_NAME}</span></a>
    <span class="room"><span class="room-word">Leikur </span><b>${code}</b></span>
    <span class="conn ${connected ? "on" : "off"}">${connected ? "Tengt" : "Tengist…"}</span>
    <button type="button" class="iconbtn" data-act="sound" aria-label="Hljóð">${soundOn() ? "🔊" : "🔇"}</button>
  </header>`;
}

function logo(): string {
  return `<svg class="logo" viewBox="0 0 64 64" aria-hidden="true"><path d="M8 22 C20 10, 30 26, 40 14 S56 16, 58 10" fill="none" stroke="url(#lg)" stroke-width="6" stroke-linecap="round"/><defs><linearGradient id="lg"><stop offset="0" stop-color="#3ee6a8"/><stop offset=".5" stop-color="#36c6d8"/><stop offset="1" stop-color="#8b7bff"/></linearGradient></defs><rect x="8" y="36" width="48" height="12" rx="6" fill="#2a3346"/><rect x="35" y="28" width="5" height="28" rx="2.5" fill="#ffe37a"/></svg>`;
}

function homeHtml(): string {
  return `<div class="home">
    <div class="hero">
      <img class="banner" src="${location.pathname.replace(/[^/]*$/, "")}cover.svg" alt="" width="300" height="400">
      ${logo()}
      <h1 class="title">${GAME_NAME}</h1>
      <p class="lead">Giskuleikur fyrir 4–8 manns. Hvert í sínum síma, í sama herbergi eða hvert heima hjá sér.</p>
    </div>
    <div class="panel">
      <button type="button" class="btn primary big" data-act="create" ${busy ? "disabled" : ""}>Stofna nýjan leik</button>
      <p class="or">eða</p>
      <form class="joinform" data-form="code">
        <label for="code-in">Kóði leiksins</label>
        <div class="row">
          <input id="code-in" class="codein" maxlength="4" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="ABCD" inputmode="text">
          <button class="btn" type="submit">Áfram</button>
        </div>
      </form>
    </div>
    ${welcomeHowToHtml(10)}
  </div>`;
}

/** The front and join pages show the illustrated walkthrough, with the rules as text beneath it. */
function welcomeHowToHtml(goal: number): string {
  return `${tourHtml()}<details class="panel howto"><summary>Svona er spilað – allar reglurnar</summary><ol>${howTo(goal).map((l) => `<li>${esc(l)}</li>`).join("")}</ol></details>`;
}

function howToHtml(goal: number): string {
  return `<section class="panel howto"><h2>Svona er spilað</h2><ol>${howTo(goal).map((l) => `<li>${esc(l)}</li>`).join("")}</ol></section>`;
}

function goneHtml(): string {
  return `<div class="center panel"><h1>Leikurinn finnst ekki</h1><p>Kóðinn <b>${esc(route!.code)}</b> passar ekki við neinn leik. Athugaðu kóðann eða stofnaðu nýjan leik.</p>
    <a class="btn primary" href="${location.pathname}" data-home>Á forsíðu</a></div>`;
}

function joinHtml(): string {
  const v = view!;
  const offline = v.players.filter((p) => !p.online);
  const teams = v.settings.mode === "teams";
  const counts = [0, 1].map((t) => v.players.filter((p) => p.team === t).length);
  const suggested: TeamId = counts[0] <= counts[1] ? 0 : 1;
  const chosen = (document.querySelector<HTMLInputElement>('input[name="team"]:checked')?.value ?? String(suggested)) as "0" | "1";
  return `<div class="join">
    <img class="banner small" src="${location.pathname.replace(/[^/]*$/, "")}cover.svg" alt="" width="300" height="400">
    <section class="panel">
      <h1>Vertu með!</h1>
      ${v.phase !== "lobby" ? `<p class="note">Leikurinn er hafinn, en þú getur samt komið inn.</p>` : ""}
      <form data-form="join" class="stack">
        <label for="name-in">Nafnið þitt</label>
        <input id="name-in" class="big-input" maxlength="${MAX_NAME}" autocomplete="given-name" placeholder="t.d. Sigga" required>
        ${teams ? `<fieldset class="teampick"><legend>Veldu lið</legend>
          ${([0, 1] as TeamId[]).map((t) => `<label class="teamopt t${t}"><input type="radio" name="team" value="${t}" ${chosen === String(t) ? "checked" : ""}><span>${teamName(t)}<small>${counts[t]} ${counts[t] === 1 ? "leikmaður" : "leikmenn"}</small></span></label>`).join("")}
        </fieldset>` : ""}
        <button class="btn primary big" type="submit">Ganga í leikinn</button>
      </form>
    </section>
    ${offline.length ? `<section class="panel">
      <h2>Ertu þegar í leiknum?</h2>
      <p>Ef þú skiptir um tæki eða datt út, ýttu á nafnið þitt:</p>
      <div class="claimlist">${offline.map((p) => `<button type="button" class="btn" data-claim="${p.id}">${esc(p.name)}</button>`).join("")}</div>
    </section>` : ""}
    ${welcomeHowToHtml(v.settings.goal)}
  </div>`;
}

function shareHtml(big = false): string {
  const code = route!.code;
  const link = shareLink(code);
  return `<section class="panel share ${big ? "share-big" : ""}">
    <div class="share-text">
      <p class="label">Kóði leiksins</p>
      <p class="bigcode">${code}</p>
      <p class="label">Allir opna þennan hlekk í sínum síma:</p>
      <p class="link">${esc(link.replace(/^https?:\/\//, ""))}</p>
      ${big ? "" : `<div class="row wrap">
        <button type="button" class="btn" data-act="copy">Afrita hlekk</button>
        ${"share" in navigator ? `<button type="button" class="btn" data-act="share">Deila…</button>` : ""}
        <a class="btn" href="#${code}/skjar" target="_blank" rel="noopener">Stór skjár (sjónvarp)</a>
      </div>`}
    </div>
    <div class="qr" aria-label="QR-kóði með hlekknum">${qrSvg(link)}</div>
  </section>`;
}

function teamsHtml(editable: boolean): string {
  const v = view!;
  const host = editable && amHost();
  const row = (p: PlayerView): string => `<li>${personLabel(p, { you: p.id === v.you })}
      ${host && v.settings.mode === "teams" ? `<button type="button" class="iconbtn" data-move="${p.id}" data-team="${1 - p.team}" aria-label="Færa í hitt liðið">⇄</button>` : ""}
      ${host && p.id !== v.you ? `<button type="button" class="iconbtn danger" data-kick="${p.id}" aria-label="Fjarlægja: ${esc(p.name)}">✕</button>` : ""}</li>`;
  if (v.settings.mode === "coop") {
    return `<section class="panel"><h2>Leikmenn (${v.players.length})</h2><ul class="people">${v.players.map(row).join("") || "<li class=muted>Enginn enn</li>"}</ul></section>`;
  }
  return `<section class="teams">${([0, 1] as TeamId[]).map((t) => {
    const ps = v.players.filter((p) => p.team === t);
    return `<div class="panel team t${t}"><h2>${teamName(t)} <small>(${ps.length})</small></h2><ul class="people">${ps.map(row).join("") || "<li class=muted>Enginn enn</li>"}</ul></div>`;
  }).join("")}</section>`;
}

function lobbyHtml(): string {
  const v = view!;
  const m = me()!;
  const host = amHost();
  const s = v.settings;
  const teams = s.mode === "teams";
  const problem = startProblem();
  return `<div class="lobby">
    ${shareHtml()}
    ${teamsHtml(true)}
    ${teams ? `<div class="row center-row"><button type="button" class="btn" data-team-self="${1 - m.team}">Skipta yfir í ${teamName((1 - m.team) as TeamId)}</button></div>` : ""}
    ${host ? `<section class="panel settings">
      <h2>Stillingar</h2>
      <div class="setting"><span>Leikhamur</span><div class="seg">
        <button type="button" class="${teams ? "on" : ""}" data-set="mode" data-val="teams">Tvö lið</button>
        <button type="button" class="${!teams ? "on" : ""}" data-set="mode" data-val="coop">Allir saman</button></div></div>
      ${teams ? `<div class="setting"><span>Stig til sigurs</span><div class="seg">${GOALS.map((g) => `<button type="button" class="${s.goal === g ? "on" : ""}" data-set="goal" data-val="${g}">${g}</button>`).join("")}</div></div>
      <div class="setting"><span>Aukagisk hins liðsins (vinstri/hægri)</span><div class="seg">
        <button type="button" class="${s.bonus ? "on" : ""}" data-set="bonus" data-val="1">Já</button>
        <button type="button" class="${!s.bonus ? "on" : ""}" data-set="bonus" data-val="0">Nei</button></div></div>
      <div class="row"><button type="button" class="btn" data-act="shuffle">🔀 Stokka liðin</button></div>`
      : `<div class="setting"><span>Fjöldi umferða</span><div class="seg">${ROUND_COUNTS.map((g) => `<button type="button" class="${s.rounds === g ? "on" : ""}" data-set="rounds" data-val="${g}">${g}</button>`).join("")}</div></div>
      ${v.best !== null ? `<p>Met hópsins: <b>${stig(v.best)}</b></p>` : ""}`}
    </section>
    ${customHtml()}
    <div class="startbox">
      ${problem ? `<p class="note">${problem}</p>` : ""}
      <button type="button" class="btn primary big" data-act="start" ${problem ? "disabled" : ""}>Hefja leik ▶</button>
    </div>`
    : `<section class="panel waiting"><p>Bíðum eftir að allir komi inn. <b>${nameOf(v.host)}</b> hefur leikinn.</p>
      <p class="muted">${teams ? `Lið að ${s.goal} stigum${s.bonus ? ", með aukagiski" : ""}.` : `Allir saman, ${s.rounds} umferðir.`}${v.customs.length ? ` ${v.customs.length} eigin kvarðar.` : ""}</p></section>`}
    ${howToHtml(s.goal)}
  </div>`;
}

function startProblem(): string | null {
  const v = view!;
  if (v.settings.mode === "coop") return v.players.length < 2 ? "Það þarf að minnsta kosti tvo leikmenn." : null;
  const [a, b] = [0, 1].map((t) => v.players.filter((p) => p.team === t).length);
  if (a < 2 || b < 2) return "Hvort lið þarf að minnsta kosti tvo leikmenn.";
  if (v.settings.customOnly && v.customs.length === 0) return "Bættu við eigin kvörðum eða slökktu á „Bara eigin kvarðar“.";
  return null;
}

function customHtml(): string {
  const v = view!;
  return `<details class="panel custom" id="custom-box" ${openAttr("custom-box")}>
    <summary><h2>Eigin kvarðar (${v.customs.length})</h2></summary>
    <p class="muted">Búðu til ykkar eigin spjöld, t.d. „Leiðinlegur frændi ↔ Skemmtilegur frændi“.</p>
    <form data-form="card" class="cardform">
      <input id="card-left" maxlength="${MAX_END}" placeholder="Vinstri endi" aria-label="Vinstri endi" required>
      <span class="end-arrow" aria-hidden="true">↔</span>
      <input id="card-right" maxlength="${MAX_END}" placeholder="Hægri endi" aria-label="Hægri endi" required>
      <button type="submit" class="btn">Bæta við</button>
    </form>
    ${v.customs.length ? `<ul class="cards">${v.customs.map((c, i) => `<li><span>${esc(c[0])} ↔ ${esc(c[1])}</span><button type="button" class="iconbtn danger" data-uncard="${i}" aria-label="Eyða">✕</button></li>`).join("")}</ul>
    <label class="check"><input type="checkbox" data-set="customOnly" ${v.settings.customOnly ? "checked" : ""}> Bara eigin kvarðar</label>` : ""}
  </details>`;
}

function boardHtml(): string {
  const v = view!;
  const r = v.round;
  if (v.settings.mode === "coop") {
    return `<section class="board coop">
      <div><span class="label">Umferð</span><b>${r?.n ?? 0} / ${v.settings.rounds}</b></div>
      <div><span class="label">Samtals</span><b>${stig(v.coopScore)}</b></div>
      <div><span class="label">Met</span><b>${v.best === null ? "–" : stig(v.best)}</b></div>
    </section>`;
  }
  const active = r?.team ?? null;
  return `<section class="board">
    ${([0, 1] as TeamId[]).map((t) => `<div class="score t${t} ${active === t ? "active" : ""}">
      <span class="tname">${teamName(t)}</span><b>${v.scores[t]}</b>${active === t && v.phase !== "over" ? `<span class="turn">á leik</span>` : ""}</div>`).join(`<div class="mid"><span class="label">Umferð ${r?.n ?? 0}</span><span class="label">Að ${v.settings.goal} stigum</span></div>`)}
  </section>`;
}

interface Status { title: string; sub?: string; tone: string }

function status(forScreen: boolean): Status {
  const v = view!;
  const r = v.round!;
  const m = forScreen ? undefined : me();
  const tone = r.team === null ? "coop" : `t${r.team}`;
  const isGiver = m?.id === r.giver;
  const onTeam = !!m && (r.team === null || m.team === r.team);
  const giver = nameOf(r.giver);
  const guessers = r.team === null ? "Hópurinn" : teamName(r.team);
  const bt = r.team === null ? null : ((1 - r.team) as TeamId);
  switch (v.phase) {
    case "clue":
      if (isGiver) return { tone, title: "Þú gefur vísbendingu!", sub: "Aðeins þú sérð markið. Finndu vísbendingu sem á heima einmitt þar á kvarðanum. Segðu hana upphátt eða skrifaðu hana hér fyrir neðan." };
      return {
        tone,
        title: `${giver} hugsar upp vísbendingu…`,
        sub: forScreen ? `${guessers} giskar í þessari umferð.` : onTeam ? (r.team === null ? "Allir giska saman. Bíddu eftir vísbendingunni." : "Liðið þitt giskar. Bíddu eftir vísbendingunni.") : `${guessers} giskar í þessari umferð.`,
      };
    case "guess": {
      const locker = nameOf(r.locker);
      const lockerOnline = !!player(r.locker)?.online;
      if (isGiver) return { tone, title: `${guessers} giskar`, sub: "Nú máttu ekki hjálpa! Bíddu og sjáðu hvar vísirinn lendir." };
      if (onTeam && !forScreen) {
        const iLock = m!.id === r.locker || !lockerOnline;
        return { tone, title: "Ræðið saman og færið vísinn", sub: iLock ? `Þegar ${r.team === null ? "hópurinn er sáttur" : "liðið er sátt"} ýtir þú á „Læsa ágiskun“.` : `${locker} læsir ágiskuninni þegar ${r.team === null ? "hópurinn er sáttur" : "liðið er sátt"}.` };
      }
      return { tone, title: `${guessers} giskar`, sub: !forScreen && v.settings.bonus && bt !== null ? "Fylgist með. Á eftir giskið þið hvort markið sé vinstra eða hægra megin við vísinn." : `${locker} læsir ágiskuninni.` };
    }
    case "bonus": {
      const bl = nameOf(r.bonusLocker);
      const btone = `t${bt}`;
      if (!forScreen && m && bt !== null && m.team === bt) {
        const iLock = m.id === r.bonusLocker || !player(r.bonusLocker)?.online;
        return { tone: btone, title: "Vinstra eða hægra megin?", sub: `Er markið vinstra eða hægra megin við vísinn? Rétt svar gefur 1 stig. ${iLock ? "Þú staðfestir valið." : `${bl} staðfestir valið.`}` };
      }
      return { tone: btone, title: `${teamName(bt!)} giskar: vinstra eða hægra megin?`, sub: "Bíðið á meðan." };
    }
    case "reveal": {
      const res = r.result!;
      const head = res.points === 4 ? "Beint í mark!" : res.points === 3 ? "Mjög nálægt!" : res.points === 2 ? "Nálægt!" : "Því miður, ekkert stig";
      return { tone, title: head, sub: undefined };
    }
    default:
      return { tone, title: "" };
  }
}

function resultHtml(): string {
  const v = view!;
  const r = v.round!;
  const res = r.result!;
  const lines: string[] = [];
  if (r.team === null) lines.push(`Hópurinn fær <b>${stig(res.points)}</b>.`);
  else lines.push(`${teamChip(r.team)} fær <b>${stig(res.points)}</b>.`);
  if (res.bonusTeam !== null) {
    lines.push(res.bonusOk ? `${teamChip(res.bonusTeam)} giskaði rétt og fær <b>1 aukastig</b>.` : `${teamChip(res.bonusTeam)} giskaði rangt.`);
  }
  const next = v.nextGiver ? `<p class="muted">Næst gefur vísbendingu: <b>${nameOf(v.nextGiver)}</b>${player(v.nextGiver) && !coop() ? ` (${teamName(player(v.nextGiver)!.team)})` : ""}</p>` : "";
  return `<section class="panel result">${lines.map((l) => `<p>${l}</p>`).join("")}${next}</section>`;
}

function clueHtml(): string {
  const r = view!.round!;
  if (view!.phase === "clue") return "";
  if (!r.clue) return `<section class="clue none"><span class="label">Vísbending</span><p>Sögð upphátt</p></section>`;
  return `<section class="clue"><span class="label">Vísbending – ${nameOf(r.giver)}</span><p>„${esc(r.clue)}“</p></section>`;
}

function actionsHtml(): string {
  const v = view!;
  const r = v.round!;
  const m = me()!;
  const isGiver = m.id === r.giver;
  switch (v.phase) {
    case "clue":
      if (!isGiver) return "";
      return `<form data-form="clue" class="panel stack clueform">
        <label for="clue-in">Vísbending (má sleppa ef þú segir hana upphátt)</label>
        <input id="clue-in" class="big-input" maxlength="${MAX_CLUE}" autocomplete="off" placeholder="Skrifaðu vísbendinguna">
        <button type="submit" class="btn primary big">Vísbending tilbúin ✓</button>
        <button type="button" class="btn" data-act="redraw">↻ Annað spjald</button>
      </form>`;
    case "guess": {
      if (!canMoveHere()) return "";
      const lockerOnline = !!player(r.locker)?.online;
      if (m.id === r.locker || !lockerOnline) return `<div class="actions"><button type="button" class="btn primary big" data-act="lock">🔒 Læsa ágiskun</button></div>`;
      return "";
    }
    case "bonus": {
      if (r.team === null || m.team === r.team) return "";
      const iLock = m.id === r.bonusLocker || !player(r.bonusLocker)?.online;
      return `<div class="actions bonus">
        <div class="row two">
          <button type="button" class="btn side ${r.bonusPick === "L" ? "on" : ""}" data-pick="L">◀ Vinstra megin</button>
          <button type="button" class="btn side ${r.bonusPick === "R" ? "on" : ""}" data-pick="R">Hægra megin ▶</button>
        </div>
        ${iLock ? `<button type="button" class="btn primary big" data-act="bonus-lock" ${r.bonusPick ? "" : "disabled"}>Staðfesta val</button>` : ""}
      </div>`;
    }
    case "reveal":
      return `<div class="actions reveal-actions"><button type="button" class="btn primary big" data-act="next">${r.result?.finished ? "Sjá úrslit ▶" : "Næsta umferð ▶"}</button></div>`;
    default:
      return "";
  }
}

function bonusPickHtml(): string {
  const v = view!;
  const r = v.round!;
  if ((v.phase !== "bonus" && v.phase !== "reveal") || !r.bonusPick || r.team === null) return "";
  return `<p class="pickline">${teamChip((1 - r.team) as TeamId)} ${v.phase === "bonus" ? "hallast að" : "valdi"}: <b>${r.bonusPick === "L" ? "◀ vinstra megin" : "hægra megin ▶"}</b></p>`;
}

function overHtml(forScreen: boolean): string {
  const v = view!;
  let head: string;
  let sub = "";
  if (v.settings.mode === "coop") {
    const max = v.settings.rounds * 4;
    head = `Þið fenguð ${stig(v.coopScore)}`;
    sub = `af ${max} mögulegum. ${v.round?.result?.newBest ? "<b>Nýtt met!</b> 🎉" : v.best !== null ? `Metið er ${stig(v.best)}.` : ""}`;
  } else {
    const w = v.round?.result?.winner ?? (v.scores[0] > v.scores[1] ? 0 : 1);
    head = `${teamName(w as TeamId)} vinnur! 🎉`;
    sub = `${teamName(0)} ${v.scores[0]} – ${v.scores[1]} ${teamName(1)}`;
  }
  const again = forScreen ? "" : amHost() ? `<button type="button" class="btn primary big" data-act="again">Nýr leikur</button>` : `<p class="muted">${nameOf(v.host)} getur byrjað nýjan leik.</p>`;
  return `<section class="panel over ${v.settings.mode === "coop" ? "coop" : `t${v.round?.result?.winner ?? 0}`}"><h1>${head}</h1><p class="big">${sub}</p>${again}</section>`;
}

function gameHtml(): string {
  const v = view!;
  if (v.phase === "over") return boardHtml() + overHtml(false) + playersHtml();
  const st = status(false);
  return `${boardHtml()}
    <section class="status ${st.tone}"><h1>${st.title}</h1>${st.sub ? `<p>${st.sub}</p>` : ""}</section>
    ${clueHtml()}
    <div id="scale-slot"></div>
    ${bonusPickHtml()}
    ${v.phase === "reveal" ? resultHtml() : ""}
    ${actionsHtml()}
    ${playersHtml()}`;
}

function playersHtml(): string {
  const v = view!;
  const host = amHost();
  const inRound = v.phase === "clue" || v.phase === "guess" || v.phase === "bonus";
  return `<details class="panel players" id="players-box" ${openAttr("players-box")}>
    <summary><h2>Leikmenn (${v.players.length})</h2></summary>
    ${teamsHtml(true)}
    ${host ? `<div class="row wrap">${inRound ? `<button type="button" class="btn" data-act="skip">⏭ Sleppa umferð</button>` : ""}
      ${v.phase !== "lobby" ? `<button type="button" class="btn" data-act="again">Hætta og fara í biðsal</button>` : ""}</div>` : ""}
    <p class="muted small">Stór skjár: <a href="#${route!.code}/skjar" target="_blank" rel="noopener">opna á sjónvarpi</a></p>
  </details>`;
}

function bigScreenHtml(): string {
  const v = view!;
  if (v.phase === "lobby") {
    return `<div class="screen-lobby">${shareHtml(true)}${teamsHtml(false)}${howToHtml(v.settings.goal)}</div>`;
  }
  if (v.phase === "over") return boardHtml() + overHtml(true);
  const st = status(true);
  return `${boardHtml()}
    <section class="status ${st.tone}"><h1>${st.title}</h1>${st.sub ? `<p>${st.sub}</p>` : ""}</section>
    ${clueHtml()}
    <div id="scale-slot"></div>
    ${bonusPickHtml()}
    ${v.phase === "reveal" ? resultHtml() : ""}
    <p class="screen-foot">Vertu með: <b>${esc(shareLink(route!.code).replace(/^https?:\/\//, ""))}</b></p>`;
}

// ---------- input ----------

app.addEventListener("click", async (e) => {
  unlockAudio();
  const t = e.target as HTMLElement;
  const el = t.closest<HTMLElement>("[data-act],[data-set],[data-claim],[data-kick],[data-move],[data-team-self],[data-uncard],[data-pick],[data-home]");
  if (!el) return;
  if (el.dataset.home !== undefined) {
    e.preventDefault();
    history.pushState(null, "", location.pathname);
    enterRoute();
    return;
  }
  if (el.dataset.set) {
    if (el instanceof HTMLInputElement) return; // the checkbox: handled by "change"
    const key = el.dataset.set;
    const raw = el.dataset.val!;
    const val = key === "mode" ? raw : key === "bonus" ? raw === "1" : Number(raw);
    sendAct({ a: "settings", settings: { [key]: val } });
    return;
  }
  if (el.dataset.claim) {
    conn?.send({ t: "claim", pid: el.dataset.claim });
    return;
  }
  if (el.dataset.kick) {
    const p = player(el.dataset.kick);
    if (p && confirm(`Fjarlægja úr leiknum: ${p.name}?`)) sendAct({ a: "kick", pid: p.id });
    return;
  }
  if (el.dataset.move) {
    sendAct({ a: "move-player", pid: el.dataset.move, team: Number(el.dataset.team) as TeamId });
    return;
  }
  if (el.dataset.teamSelf) {
    sendAct({ a: "team", team: Number(el.dataset.teamSelf) as TeamId });
    return;
  }
  if (el.dataset.uncard) {
    sendAct({ a: "remove-card", index: Number(el.dataset.uncard) });
    return;
  }
  if (el.dataset.pick) {
    sendAct({ a: "pick", side: el.dataset.pick as "L" | "R" });
    return;
  }
  switch (el.dataset.act) {
    case "sound":
      setSound(!soundOn());
      unlockAudio();
      render();
      return;
    case "create": {
      busy = true;
      render();
      try {
        const res = await fetch("api/rooms", { method: "POST" });
        const body = (await res.json()) as { code?: string; error?: string };
        if (!body.code) throw new Error(body.error);
        location.hash = body.code;
      } catch {
        toast("Gat ekki stofnað leik. Athugaðu nettenginguna og reyndu aftur.");
      } finally {
        busy = false;
        render();
      }
      return;
    }
    case "copy":
      try {
        await navigator.clipboard.writeText(shareLink(route!.code));
        toast("Hlekkurinn er kominn á klippiborðið.");
      } catch {
        prompt("Afritaðu hlekkinn:", shareLink(route!.code));
      }
      return;
    case "share":
      try {
        await navigator.share({ title: GAME_NAME, text: `Vertu með í Kvarðanum! Kóði: ${route!.code}`, url: shareLink(route!.code) });
      } catch {
        /* cancelled */
      }
      return;
    case "skip":
      if (confirm("Sleppa þessari umferð? Sama lið fær nýja umferð.")) sendAct({ a: "skip" });
      return;
    case "again":
      if (view?.phase === "over" || confirm("Hætta í þessum leik og fara aftur í biðsalinn? Stigin núllast.")) sendAct({ a: "again" });
      return;
    case "start":
    case "shuffle":
    case "redraw":
    case "lock":
    case "bonus-lock":
    case "next":
      sendAct({ a: el.dataset.act });
      return;
  }
});

app.addEventListener(
  "toggle",
  (e) => {
    const d = e.target as HTMLDetailsElement;
    if (!d.id) return;
    if (d.open) openDetails.add(d.id);
    else openDetails.delete(d.id);
  },
  true,
);

app.addEventListener("change", (e) => {
  const t = e.target as HTMLInputElement;
  if (t.dataset.set === "customOnly") sendAct({ a: "settings", settings: { customOnly: t.checked } });
});

app.addEventListener("submit", (e) => {
  e.preventDefault();
  unlockAudio();
  const f = e.target as HTMLFormElement;
  const val = (id: string) => (document.getElementById(id) as HTMLInputElement | null)?.value ?? "";
  const clear = (id: string) => {
    const el = document.getElementById(id) as HTMLInputElement | null;
    if (el) el.value = "";
  };
  switch (f.dataset.form) {
    case "code": {
      const code = val("code-in").trim().toUpperCase();
      if (!/^[A-Z]{4}$/.test(code)) {
        toast("Kóðinn er fjórir stafir.");
        return;
      }
      location.hash = code;
      return;
    }
    case "join": {
      const team = (f.querySelector<HTMLInputElement>('input[name="team"]:checked')?.value ?? null) as string | null;
      conn?.send({ t: "join", name: val("name-in"), team: team === null ? null : Number(team) });
      return;
    }
    case "clue":
      sendAct({ a: "ready", clue: val("clue-in") });
      clear("clue-in");
      return;
    case "card":
      sendAct({ a: "add-card", left: val("card-left"), right: val("card-right") });
      clear("card-left");
      clear("card-right");
      document.getElementById("card-left")?.focus();
      return;
  }
});

window.addEventListener("hashchange", enterRoute);
window.addEventListener("popstate", enterRoute);
bindTour(render);
enterRoute();

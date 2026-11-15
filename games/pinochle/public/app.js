import { Table, card, meldOf, team, SYM, SUIT_NAMES, RANK_LABEL, TARGET } from './engine.js';

const $app = document.getElementById('app');
const $modal = document.getElementById('modal');
const $toast = document.getElementById('toast');
const store = {
  get: (k, d = '') => { try { return localStorage.getItem(k) ?? d; } catch { return d; } },
  set: (k, v) => { try { localStorage.setItem(k, v); } catch {} },
  del: (k) => { try { localStorage.removeItem(k); } catch {} },
};
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const isRed = (s) => s === 1 || s === 3;

const ui = {
  screen: 'home', name: store.get('pin.name', ''), ctl: null, view: null, room: null,
  sel: new Set(), bid: 20, selKey: '', prevTrick: new Set(), joinCode: '',
};
let token = store.get('pin.token');
if (!token) { token = Math.random().toString(36).slice(2) + Date.now().toString(36); store.set('pin.token', token); }

let toastT;
function toast(msg) {
  $toast.textContent = msg; $toast.classList.add('show');
  clearTimeout(toastT); toastT = setTimeout(() => $toast.classList.remove('show'), 1800);
}

// ---------------- controllers ----------------
function startSolo() {
  stopCtl();
  const seats = [
    { name: ui.name || 'You', human: true, connected: true },
    { name: 'Ava', human: false, connected: true },
    { name: 'Max', human: false, connected: true },
    { name: 'Zoe', human: false, connected: true },
  ];
  const table = new Table(seats, (t) => { ui.view = t.viewFor(0); render(); });
  ui.ctl = { kind: 'solo', send: (a) => { const r = table.act(0, a); if (!r.ok) toast(r.err); }, stop: () => table.stop() };
  ui.view = table.viewFor(0);
  ui.screen = 'game';
  render();
}

let ws = null, wsRetry = null;
function stopCtl() {
  ui.ctl?.stop?.(); ui.ctl = null; ui.view = null; ui.room = null;
}
function connect(first) {
  clearTimeout(wsRetry);
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  try { ws = new WebSocket(`${proto}://${location.host}/ws`); } catch { toast('Online play needs the game server.'); return; }
  ws.onopen = () => { ws.onopen = null; first(); };
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    if (m.t === 'room') {
      ui.room = m; store.set('pin.room', m.code);
      ui.view = m.view;
      ui.screen = m.started ? 'game' : 'lobby';
      render();
    } else if (m.t === 'error') {
      toast(m.msg);
      if (!ui.room) { store.del('pin.room'); stopCtl(); ui.screen = 'home'; render(); }
    } else if (m.t === 'kicked') {
      toast('Signed in from another device.'); goHome();
    }
  };
  ws.onclose = () => {
    if (ui.ctl?.kind !== 'online') return;
    toast('Connection lost — reconnecting…');
    wsRetry = setTimeout(() => connect(() => wsend({ t: 'join', code: ui.room.code, name: ui.name, token })), 2000);
  };
  ws.onerror = () => { if (!ui.ctl) toast('Could not reach the game server.'); };
}
const wsend = (m) => ws && ws.readyState === 1 && ws.send(JSON.stringify(m));
function online(first) {
  stopCtl();
  ui.ctl = { kind: 'online', send: (a) => wsend({ t: 'act', action: a }), stop: () => { clearTimeout(wsRetry); wsend({ t: 'leave' }); ws?.close(); ws = null; } };
  connect(first);
}
function goHome() {
  stopCtl(); store.del('pin.room'); ui.screen = 'home'; render();
}

// ---------------- helpers ----------------
function cardHTML(id, cls = '', extra = '') {
  const c = card(id);
  return `<div class="card ${isRed(c.s) ? 'red' : ''} ${cls}" data-id="${id}" ${extra}><span class="idx">${RANK_LABEL[c.r]}<br>${SYM[c.s]}</span><span class="big">${SYM[c.s]}</span></div>`;
}
const backs = (n) => `<div class="backs">${'<div class="card back"></div>'.repeat(Math.min(n, 12))}</div>`;
const mini = (ids) => ids.slice().sort((a, b) => card(b).r - card(a).r).map((i) => { const c = card(i); return `<span class="mc ${isRed(c.s) ? 'red' : ''}">${RANK_LABEL[c.r]}${SYM[c.s]}</span>`; }).join('');
const nm = (v, seat) => esc(v.seats[seat].name);
const pos = (v, seat) => (seat - v.me + 4) % 4; // 0 bottom, 1 left, 2 top, 3 right
const rel = (v, seat) => (seat === v.me ? 'You' : nm(v, seat));

// ---------------- screens ----------------
function render() {
  if (ui.screen === 'home') return renderHome();
  if (ui.screen === 'lobby') return renderLobby();
  if (ui.screen === 'game' && ui.view) return renderGame();
}

function renderHome() {
  const joinParam = new URLSearchParams(location.search).get('join');
  if (joinParam && !ui.joinCode) ui.joinCode = joinParam.toUpperCase().slice(0, 4);
  $app.innerHTML = `
  <div class="screen">
    <div class="suits"><span>♠</span><span class="r">♥</span><span>♣</span><span class="r">♦</span></div>
    <h1 class="logo">Pinochle<small>Partnership auction pinochle</small></h1>
    <input id="name" maxlength="14" placeholder="Your name" value="${esc(ui.name)}" autocomplete="nickname">
    <button class="big" data-act="solo">Play solo vs computer</button>
    <button class="big ghost" data-act="create">Create online game</button>
    <div class="row">
      <input id="code" maxlength="4" placeholder="CODE" value="${esc(ui.joinCode)}" autocapitalize="characters" style="text-transform:uppercase;text-align:center;letter-spacing:6px;font-weight:800">
      <button class="ghost" data-act="join" style="min-width:110px">Join</button>
    </div>
    <button class="ghost" data-act="rules">How to play</button>
    <p class="sub">You and your partner (across the table) against two opponents. First team to ${TARGET} wins.</p>
  </div>`;
}

function renderLobby() {
  const r = ui.room;
  const link = `${location.origin}${location.pathname}?join=${r.code}`;
  const slot = (i) => {
    const x = r.seats[i], me = i === r.you;
    return `<div class="slot ${me ? 'me' : ''}">${x
      ? `<span>${esc(x.name)}${me ? ' (you)' : ''}${i === r.host ? ' ★' : ''} ${x.connected ? '' : '<span class="dim">offline</span>'}</span>`
      : `<span class="dim">Empty — a bot will play</span>`}
      ${!x ? `<button class="ghost" data-act="sit" data-seat="${i}">Sit here</button>` : ''}</div>`;
  };
  $app.innerHTML = `
  <div class="screen">
    <div class="sub">Game code — share it with friends</div>
    <div class="code">${r.code}</div>
    <div class="row"><button class="ghost" data-act="share" data-link="${esc(link)}">Share invite link</button></div>
    <div class="teams">
      <div class="team"><h4>Team A — partners sit across</h4>${slot(0)}${slot(2)}</div>
      <div class="team"><h4>Team B — partners sit across</h4>${slot(1)}${slot(3)}</div>
    </div>
    ${r.you === r.host
      ? `<button class="big" data-act="start">Start game</button><p class="sub">Empty seats are filled with computer players.</p>`
      : `<p class="sub">Waiting for the host to start…</p>`}
    <button class="ghost" data-act="home">Leave</button>
  </div>`;
}

function statusText(v) {
  const s = v;
  const t = s.turn;
  const me = s.me;
  switch (s.phase) {
    case 'bid': return t === me ? 'Your bid — bid or pass' : `${nm(v, t)} is bidding…`;
    case 'trump': return s.declarer === me ? 'You won the bid — name trump' : `${nm(v, s.declarer)} is choosing trump…`;
    case 'give1': return t === me ? `Pick your 3 best cards to pass to ${nm(v, s.declarer)}` : s.declarer === me ? 'Your partner is passing you 3 cards…' : `${nm(v, t)} is passing 3 cards…`;
    case 'give2': return t === me ? 'Pass 3 cards back to your partner' : `${nm(v, t)} is passing 3 cards back…`;
    case 'play':
      if (s.pending) return `${rel(v, s.trickWinner)} ${s.trickWinner === me ? 'win' : 'wins'} the trick`;
      return t === me ? 'Your turn — tap a card, tap again to play' : `${nm(v, t)} to play…`;
  }
  return '';
}

function renderGame() {
  const v = ui.view, me = v.me;
  const myTeam = team(me);
  const key = `${v.handNo}|${v.phase}|${v.turn}`;
  if (key !== ui.selKey) { ui.sel = new Set(); ui.selKey = key; }
  if (v.phase === 'bid' && ui.bid < v.minBid) ui.bid = v.minBid;
  if (v.phase === 'bid' && ui.bid > v.minBid + 60) ui.bid = v.minBid;

  // layout sizes
  const w = Math.min(window.innerWidth, 900), h = window.innerHeight, n = v.hand.length;
  let cw = Math.min(w < 500 ? 60 : 76, h * 0.16);
  cw = Math.min(cw, (w - 16) / (1 + 0.4 * (n - 1)));
  const slice = Math.min(cw * 0.85, (w - 16 - cw) / Math.max(1, n - 1));
  const ov = cw - slice;

  const seatHTML = (i) => {
    const p = pos(v, i);
    if (p === 0) return '';
    const cls = ['', 'left', 'top', 'right'][p];
    const bid = v.bids[i];
    const bub = v.phase === 'bid' && bid != null ? `<div class="bubble ${bid === 'pass' ? 'pass' : ''}">${bid === 'pass' ? 'Pass' : bid}</div>` : '';
    return `<div class="seat ${cls}">
      <div class="chip ${v.turn === i ? 'turn' : ''} ${team(i) === myTeam ? 'mate' : ''}">${nm(v, i)}${i === v.dealer ? '<span class="tag">dealer</span>' : ''}${v.phase !== 'bid' && i === v.declarer ? '<span class="tag">★ bid</span>' : ''}${v.seats[i].human && !v.seats[i].connected ? '<span class="tag">offline</span>' : ''}</div>
      ${bub}${backs(v.counts[i])}<div class="cnt">${v.counts[i]} cards</div></div>`;
  };

  // trick
  let trickHTML = '';
  const curIds = new Set();
  const showTrick = v.trick.length ? v.trick : [];
  for (const t of showTrick) {
    curIds.add(t.card);
    const isNew = !ui.prevTrick.has(t.card);
    const win = v.pending && t.seat === v.trickWinner ? 'win' : '';
    trickHTML += cardHTML(t.card, `p${pos(v, t.seat)} ${isNew ? 'new' : ''} ${win}`);
  }
  ui.prevTrick = curIds;

  // hand
  const canSel = (v.phase === 'give1' || v.phase === 'give2') && v.turn === me;
  const handHTML = v.hand.map((id) => {
    let cls = '';
    if (v.phase === 'play' && v.turn === me && !v.pending) cls = v.legal.includes(id) ? 'can' : 'dim';
    if (ui.sel.has(id)) cls += ' sel';
    return cardHTML(id, cls, '');
  }).join('');

  // panel
  let panel = '';
  const myMelds = [0, 1, 2, 3].map((t) => ({ t, m: meldOf(v.hand, t).total }));
  if (v.phase === 'bid' && v.turn === me) {
    panel = `<div class="row"><div class="stepper"><button class="ghost" data-act="bid-" >−</button><b>${ui.bid}</b><button class="ghost" data-act="bid+">+</button><button class="ghost" data-act="bid5">+5</button></div>
      <button data-act="bid">Bid ${ui.bid}</button><button class="ghost" data-act="pass">Pass</button></div>
      <div class="hints">Your meld by trump: ${myMelds.map((x) => `<span style="color:${isRed(x.t) ? '#ff8a7a' : '#fff'}">${SYM[x.t]} ${x.m}</span>`).join(' · ')}${v.high ? ` &nbsp;|&nbsp; high bid ${v.high}` : ''}</div>`;
  } else if (v.phase === 'trump' && v.declarer === me) {
    panel = `<div class="row suitbtns">${[0, 1, 2, 3].map((s) => `<button class="${isRed(s) ? 'r' : ''}" data-act="trump" data-suit="${s}">${SYM[s]}<small>${myMelds[s].m} meld</small></button>`).join('')}</div>`;
  } else if (canSel) {
    panel = `<div class="row"><button data-act="give" ${ui.sel.size === 3 ? '' : 'disabled'}>Pass ${ui.sel.size}/3 cards</button></div>
      ${v.phase === 'give1' ? '<div class="hints">Tip: trump and aces help your partner most — keep cards that make your own meld.</div>' : ''}`;
  }

  const bidInfo = v.phase === 'bid' || !v.high ? (v.high ? `Bid ${v.high}` : '') : `${nm(v, v.declarer)} bid ${v.high}`;
  const trumpInfo = v.trump >= 0 ? `<span style="color:${isRed(v.trump) ? '#ff8a7a' : '#fff'};font-size:18px">${SYM[v.trump]}</span> trump` : '';
  const pointsInfo = v.phase === 'play' ? `card points ${v.counters[myTeam]}–${v.counters[1 - myTeam]}` : '';

  $app.innerHTML = `
  <div id="game" style="--cw:${cw}px;--ov:${ov}px">
    <div class="bar">
      <div class="sc"><div><span>US</span><b>${v.scores[myTeam]}</b></div><div><span>THEM</span><b>${v.scores[1 - myTeam]}</b></div></div>
      <div class="info">${[bidInfo, trumpInfo].filter(Boolean).join(' · ')}${pointsInfo ? `<small>${pointsInfo}</small>` : ''}</div>
      <button class="menu" data-act="menu" aria-label="Menu">☰</button>
    </div>
    <div class="felt">
      ${[1, 2, 3].map((i) => seatHTML((me + i) % 4)).join('')}
      <div class="trick">${trickHTML}</div>
      ${sheetHTML(v)}
    </div>
    <div class="status ${v.turn === me ? 'me' : ''}">${statusText(v)}</div>
    <div class="panel">${panel}</div>
    <div class="hand" data-hand>${handHTML}</div>
  </div>`;
}

function itemsHTML(m) {
  if (!m.items.length) return '<div class="mi"><span class="n">no meld</span></div>';
  return m.items.map((it) => `<div class="mi"><span class="n">${esc(it.name)} <b>${it.pts}</b></span>${mini(it.cards)}</div>`).join('');
}

function sheetHTML(v) {
  const me = v.me, myT = team(me);
  if (v.phase === 'meld') {
    const order = [me, (me + 2) % 4, (me + 1) % 4, (me + 3) % 4];
    const tm = [0, 1].map((t) => v.meld.reduce((a, m, i) => a + (team(i) === t ? m.total : 0), 0));
    const waiting = v.ready.filter((r, i) => !r && v.seats[i].human && v.seats[i].connected).length;
    return `<div class="sheet"><h3>${SYM[v.trump]} ${SUIT_NAMES[v.trump]} is trump · ${nm(v, v.declarer)} bid ${v.high}</h3>
      ${order.map((i) => `<div class="pl ${team(i) === myT ? 'us' : ''}"><div class="hd"><span>${rel(v, i)}${team(i) === myT && i !== me ? ' (partner)' : ''}</span><span>${v.meld[i].total}</span></div>${itemsHTML(v.meld[i])}</div>`).join('')}
      <div class="tot"><span>Your team meld</span><span>${tm[myT]}</span></div>
      <div class="tot"><span>Their meld</span><span>${tm[1 - myT]}</span></div>
      <button class="big" data-act="ready" ${v.ready[me] ? 'disabled' : ''}>${v.ready[me] ? 'Waiting for others…' : 'Play the hand'}</button></div>`;
  }
  if (v.phase === 'hand' || v.phase === 'over') {
    const r = v.result, dt = r.dteam;
    const row = (t, label) => {
      const p = r.parts[t];
      const note = !p.took ? '<div class="sub">took no tricks — no points</div>' : '';
      return `<tr><td>${label}${t === dt ? ' ★' : ''}</td><td>${p.meld}</td><td>${p.counters}</td><td class="${p.delta < 0 ? 'badc' : 'good'}">${p.delta > 0 ? '+' : ''}${p.delta}</td><td><b>${v.scores[t]}</b></td></tr>`;
    };
    const iWon = v.winner === myT;
    const head = v.phase === 'over'
      ? `<h3>${iWon ? '🏆 Your team wins!' : 'Your team loses'}</h3>`
      : `<h3>${nm(v, r.declarer)}'s team ${r.made ? 'made' : '<span class="badc">was set on</span>'} ${r.bid}</h3>`;
    const needs = r.made ? '' : `<p class="sub">They scored ${r.parts[dt].base} — short of the bid, so they lose ${r.bid}.</p>`;
    const done = v.ready[me];
    return `<div class="sheet">${head}${needs}
      <table class="res"><tr><th></th><th>Meld</th><th>Cards</th><th>Hand</th><th>Total</th></tr>${row(myT, 'Us')}${row(1 - myT, 'Them')}</table>
      ${r.parts.some((p) => !p.took) ? '<p class="sub">A team that wins no tricks scores nothing for the hand.</p>' : ''}
      <button class="big" data-act="ready" ${done ? 'disabled' : ''}>${done ? 'Waiting for others…' : v.phase === 'over' ? 'Play again' : 'Next hand'}</button></div>`;
  }
  return '';
}

// ---------------- modals ----------------
function modal(html) {
  if (!html) { $modal.classList.add('hidden'); $modal.innerHTML = ''; return; }
  $modal.innerHTML = `<div class="box">${html}</div>`;
  $modal.classList.remove('hidden');
}
const RULES = `<h2>How to play</h2>
<p>Four players, two partnerships (you and the player across from you). 48-card deck: A 10 K Q J 9 in each suit, twice. Card rank high→low: <b>A 10 K Q J 9</b>. First team to <b>${TARGET}</b> wins.</p>
<h4>1. Bidding</h4><p>Starting left of the dealer, each player bids (minimum 20) or passes; once you pass you are out. Highest bidder names <b>trump</b>. If all pass, the dealer is stuck with the minimum.</p>
<h4>2. Passing</h4><p>The bidder's partner passes their 3 best cards to the bidder, who then passes any 3 cards back.</p>
<h4>3. Meld</h4><p>Everyone shows meld; it's added up per team.</p>
<ul><li>Run (A-10-K-Q-J of trump) 15 · double run 150</li><li>Royal marriage (K+Q trump) 4 · other marriage 2</li><li>Dix (trump 9) 1 each</li><li>Pinochle (J♦ + Q♠) 4 · double 30</li><li>Aces around 10 (all 8: 100) · Kings 8 (80) · Queens 6 (60) · Jacks 4 (40)</li></ul>
<h4>4. Play</h4><p>Bidder leads. You must follow suit and play a higher card if you can. If you can't follow, you must trump (and over-trump if possible). Highest trump, else highest card of the led suit, wins.</p>
<h4>5. Scoring</h4><p>Aces, tens and kings are worth 1 each; last trick 1 (25 total). A team's hand score = meld + points taken, but only if it won at least one trick. If the bidding team falls short of its bid it <b>loses the bid</b> instead; the other team keeps what it earned.</p>`;
function rulesModal() { modal(`${RULES}<button data-act="close">Got it</button>`); }
function menuModal() {
  modal(`<h2>Menu</h2><button class="ghost" data-act="rules2">How to play</button><button class="ghost" data-act="quit">Quit to main menu</button><button data-act="close">Back to game</button>`);
}

// ---------------- events ----------------
document.addEventListener('click', (e) => {
  const handCard = e.target.closest('[data-hand] .card');
  if (handCard) return onCard(+handCard.dataset.id);
  const b = e.target.closest('[data-act]');
  if (!b) return;
  const a = b.dataset.act, v = ui.view;
  const send = (x) => ui.ctl?.send(x);
  switch (a) {
    case 'solo': saveName(); startSolo(); break;
    case 'create': saveName(); online(() => wsend({ t: 'create', name: ui.name || 'Player', token })); break;
    case 'join': {
      saveName();
      const code = document.getElementById('code').value.trim().toUpperCase();
      if (code.length !== 4) return toast('Enter the 4-letter code');
      online(() => wsend({ t: 'join', code, name: ui.name || 'Player', token }));
      break;
    }
    case 'rules': case 'rules2': rulesModal(); break;
    case 'close': modal(null); break;
    case 'menu': menuModal(); break;
    case 'quit': modal(null); goHome(); break;
    case 'home': goHome(); break;
    case 'sit': wsend({ t: 'sit', seat: +b.dataset.seat }); break;
    case 'start': wsend({ t: 'start' }); break;
    case 'share': {
      const link = b.dataset.link;
      if (navigator.share) navigator.share({ title: 'Pinochle', text: 'Join my pinochle game!', url: link }).catch(() => {});
      else navigator.clipboard?.writeText(link).then(() => toast('Link copied'), () => toast(link));
      break;
    }
    case 'bid-': ui.bid = Math.max(v.minBid, ui.bid - 1); render(); break;
    case 'bid+': ui.bid = Math.min(250, ui.bid + 1); render(); break;
    case 'bid5': ui.bid = Math.min(250, ui.bid + 5); render(); break;
    case 'bid': send({ type: 'bid', amount: ui.bid }); break;
    case 'pass': send({ type: 'pass' }); break;
    case 'trump': send({ type: 'trump', suit: +b.dataset.suit }); break;
    case 'give': if (ui.sel.size === 3) send({ type: 'give', cards: [...ui.sel] }); break;
    case 'ready': send({ type: 'ready' }); break;
  }
});
function saveName() {
  const el = document.getElementById('name');
  if (el) { ui.name = el.value.trim().slice(0, 14); store.set('pin.name', ui.name); }
  const c = document.getElementById('code');
  if (c) ui.joinCode = c.value.toUpperCase();
}
function onCard(id) {
  const v = ui.view;
  if (!v || v.turn !== v.me) return;
  if (v.phase === 'play' && !v.pending) {
    if (!v.legal.includes(id)) return toast('Follow suit, beat the trick if you can, or trump');
    if (ui.sel.has(id)) { ui.ctl.send({ type: 'play', card: id }); ui.sel = new Set(); }
    else { ui.sel = new Set([id]); render(); }
  } else if (v.phase === 'give1' || v.phase === 'give2') {
    if (ui.sel.has(id)) ui.sel.delete(id);
    else if (ui.sel.size < 3) ui.sel.add(id);
    render();
  }
}
window.addEventListener('resize', () => { if (ui.screen === 'game') render(); });

// ---------------- boot ----------------
if ('serviceWorker' in navigator && location.protocol.startsWith('http')) navigator.serviceWorker.register('sw.js').catch(() => {});
render();
// resume an online game after a reload
const savedRoom = store.get('pin.room');
if (savedRoom && ui.name !== undefined) online(() => wsend({ t: 'join', code: savedRoom, name: ui.name || 'Player', token }));

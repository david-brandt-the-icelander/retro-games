// Pinochle engine — shared by the browser (solo play) and the Node server (online play).
// Four-player partnership auction pinochle, 48-card deck. Seats 0..3 clockwise; teams are 0&2 vs 1&3.

export const SUITS = ['S', 'H', 'C', 'D'];
export const SYM = ['♠', '♥', '♣', '♦'];
export const SUIT_NAMES = ['Spades', 'Hearts', 'Clubs', 'Diamonds'];
export const RANK_LABEL = ['9', 'J', 'Q', 'K', '10', 'A']; // index = strength
export const TARGET = 150;
export const MAX_BID = 250;
export const MIN_BID = 20;

// id = suit*12 + rank*2 + copy
export const card = (id) => ({ id, s: (id / 12) | 0, r: ((id % 12) / 2) | 0 });
export const pts = (c) => (c.r >= 3 ? 1 : 0); // K, 10, A are counters
export const team = (seat) => seat % 2;
export const sortHand = (ids) =>
  ids.slice().sort((a, b) => {
    const x = card(a), y = card(b);
    return x.s - y.s || y.r - x.r || a - b;
  });

// ---------- meld ----------
export function meldOf(ids, trump) {
  const cs = ids.map(card);
  const by = (s, r) => cs.filter((c) => c.s === s && c.r === r);
  const cnt = (s, r) => by(s, r).length;
  const items = [];
  const add = (name, p, cards) => items.push({ name, pts: p, cards: cards.map((c) => c.id) });
  let n = 0;
  if (trump >= 0) {
    const run = [5, 4, 3, 2, 1];
    n = Math.min(...run.map((r) => cnt(trump, r)));
    if (n >= 2) add('Double run', 150, run.flatMap((r) => by(trump, r)));
    else if (n === 1) add('Run', 15, run.flatMap((r) => by(trump, r).slice(0, 1)));
  }
  for (let s = 0; s < 4; s++) {
    let m = Math.min(cnt(s, 3), cnt(s, 2));
    if (s === trump) m -= Math.min(n, 2); // the run already includes its marriage
    if (m > 0) {
      const royal = s === trump;
      const name = (m > 1 ? 'Double ' : '') + (royal ? 'royal marriage' : `marriage ${SYM[s]}`);
      add(name, m * (royal ? 4 : 2), [...by(s, 3).slice(0, m), ...by(s, 2).slice(0, m)]);
    }
  }
  if (trump >= 0) {
    const d = cnt(trump, 0);
    if (d > 0) add(d > 1 ? 'Double dix' : 'Dix', d, by(trump, 0));
  }
  const p = Math.min(cnt(3, 1), cnt(0, 2));
  if (p > 0) add(p > 1 ? 'Double pinochle' : 'Pinochle', p > 1 ? 30 : 4, [...by(3, 1), ...by(0, 2)]);
  for (const [r, name, one, two] of [[5, 'Aces', 10, 100], [3, 'Kings', 8, 80], [2, 'Queens', 6, 60], [1, 'Jacks', 4, 40]]) {
    const m = Math.min(...[0, 1, 2, 3].map((s) => cnt(s, r)));
    if (m > 0) {
      add(m > 1 ? `${name} around ×2` : `${name} around`, m > 1 ? two : one,
        [0, 1, 2, 3].flatMap((s) => by(s, r).slice(0, m)));
    }
  }
  return { total: items.reduce((a, i) => a + i.pts, 0), items };
}

// ---------- trick rules ----------
// Must follow suit and beat the current best card of the led suit if possible; if void, must trump
// (and over-trump if possible); otherwise anything.
export function legalPlays(hand, trick, trump) {
  if (!trick.length) return hand;
  const led = trick[0].card.s;
  const suited = hand.filter((c) => c.s === led);
  if (suited.length) {
    if (led !== trump && trick.some((t) => t.card.s === trump)) return suited;
    const hi = Math.max(...trick.filter((t) => t.card.s === led).map((t) => t.card.r));
    const higher = suited.filter((c) => c.r > hi);
    return higher.length ? higher : suited;
  }
  const trumps = hand.filter((c) => c.s === trump);
  if (trumps.length) {
    const hiT = Math.max(-1, ...trick.filter((t) => t.card.s === trump).map((t) => t.card.r));
    const over = trumps.filter((c) => c.r > hiT);
    return over.length ? over : trumps;
  }
  return hand;
}

export const beats = (c, best, trump) => (c.s === best.s ? c.r > best.r : c.s === trump);
export function winnerOf(trick, trump) {
  let best = trick[0];
  for (const t of trick.slice(1)) if (beats(t.card, best.card, trump)) best = t;
  return best.seat;
}

const shuffle = (a) => {
  for (let i = a.length - 1; i > 0; i--) {
    const j = (Math.random() * (i + 1)) | 0;
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
const bad = (err) => ({ ok: false, err });
const OK = { ok: true };

// ---------- game state machine ----------
// phases: bid → trump → give1 → give2 → meld → play → hand → (bid …) | over
export class Game {
  constructor() {
    this.newGame();
  }

  newGame() {
    this.s = { scores: [0, 0], dealer: (Math.random() * 4) | 0, handNo: 0, log: [], winner: -1 };
    this.deal(false);
  }

  say(seat, text) {
    this.s.log.push({ seat, text });
    if (this.s.log.length > 40) this.s.log.shift();
  }

  deal(rotate = true) {
    const s = this.s;
    if (rotate) s.dealer = (s.dealer + 1) % 4;
    s.handNo++;
    const ids = shuffle([...Array(48).keys()]);
    Object.assign(s, {
      phase: 'bid',
      turn: (s.dealer + 1) % 4,
      hands: [0, 1, 2, 3].map((i) => sortHand(ids.slice(i * 12, i * 12 + 12))),
      bids: [null, null, null, null],
      passed: [false, false, false, false],
      high: 0, bidder: -1, declarer: -1, trump: -1,
      trick: [], pending: null, trickWinner: -1, lastTrick: null,
      tricks: [0, 0], counters: [0, 0], meld: null,
      ready: [false, false, false, false], result: null,
    });
    this._max = [];
  }

  tcards() {
    return this.s.trick.map((t) => ({ seat: t.seat, card: card(t.card) }));
  }

  legal(seat) {
    const s = this.s;
    return legalPlays(s.hands[seat].map(card), this.tcards(), s.trump).map((c) => c.id);
  }

  act(seat, a) {
    const s = this.s;
    if (!a || typeof a !== 'object') return bad('bad action');
    switch (s.phase) {
      case 'bid': {
        if (seat !== s.turn) return bad('not your turn');
        if (a.type === 'pass') {
          s.passed[seat] = true;
          s.bids[seat] = 'pass';
          this.say(seat, 'passes');
        } else if (a.type === 'bid') {
          const n = a.amount | 0, min = Math.max(MIN_BID, s.high + 1);
          if (n < min || n > MAX_BID) return bad('bid out of range');
          s.high = n; s.bidder = seat; s.bids[seat] = n;
          this.say(seat, `bids ${n}`);
        } else return bad('bid or pass');
        this.bidAdvance();
        return OK;
      }
      case 'trump': {
        if (seat !== s.declarer || a.type !== 'trump') return bad('declarer names trump');
        const t = a.suit | 0;
        if (t < 0 || t > 3) return bad('bad suit');
        s.trump = t;
        this.say(seat, `names ${SUIT_NAMES[t]} trump`);
        s.phase = 'give1';
        s.turn = (s.declarer + 2) % 4;
        return OK;
      }
      case 'give1':
      case 'give2': {
        if (seat !== s.turn || a.type !== 'give') return bad('not your turn');
        const ids = a.cards;
        if (!Array.isArray(ids) || ids.length !== 3 || new Set(ids).size !== 3 ||
            !ids.every((i) => s.hands[seat].includes(i))) return bad('give exactly 3 of your cards');
        const to = s.phase === 'give1' ? s.declarer : (s.declarer + 2) % 4;
        s.hands[seat] = s.hands[seat].filter((i) => !ids.includes(i));
        s.hands[to] = sortHand([...s.hands[to], ...ids]);
        this.say(seat, `passes 3 cards to ${s.phase === 'give1' ? 'declarer' : 'partner'}`);
        if (s.phase === 'give1') {
          s.phase = 'give2'; s.turn = s.declarer;
        } else {
          s.meld = s.hands.map((h) => meldOf(h, s.trump));
          s.phase = 'meld'; s.turn = -1;
          s.ready = [false, false, false, false];
        }
        return OK;
      }
      case 'meld': case 'hand': case 'over': {
        if (a.type !== 'ready') return bad('press continue');
        s.ready[seat] = true;
        if (s.ready.every(Boolean)) {
          if (s.phase === 'meld') {
            s.phase = 'play'; s.turn = s.declarer; s.trick = [];
          } else if (s.phase === 'hand') this.deal(true);
          else this.newGame();
        }
        return OK;
      }
      case 'play': {
        if (s.pending || seat !== s.turn || a.type !== 'play') return bad('not your turn');
        if (!s.hands[seat].includes(a.card)) return bad('not in hand');
        if (!this.legal(seat).includes(a.card)) return bad('illegal play');
        s.hands[seat] = s.hands[seat].filter((i) => i !== a.card);
        s.trick.push({ seat, card: a.card });
        if (s.trick.length < 4) s.turn = (seat + 1) % 4;
        else {
          s.pending = 'trick'; s.turn = -1;
          s.trickWinner = winnerOf(this.tcards(), s.trump);
        }
        return OK;
      }
    }
    return bad('no such phase');
  }

  bidAdvance() {
    const s = this.s;
    const active = [0, 1, 2, 3].filter((i) => !s.passed[i]);
    if (active.length === 1) {
      if (s.bidder < 0) { // everyone passed: dealer is stuck with the minimum
        s.bidder = active[0]; s.high = MIN_BID;
        this.say(s.bidder, `is stuck with the bid at ${MIN_BID}`);
      }
      s.declarer = s.bidder;
      s.phase = 'trump'; s.turn = s.declarer;
      this.say(s.declarer, `wins the bid at ${s.high}`);
      return;
    }
    let t = s.turn;
    do { t = (t + 1) % 4; } while (s.passed[t]);
    s.turn = t;
  }

  // Called by the table after the finished trick has been on display for a moment.
  resolveTrick() {
    const s = this.s;
    if (s.pending !== 'trick') return;
    const w = s.trickWinner, t = team(w);
    s.counters[t] += s.trick.reduce((a, x) => a + pts(card(x.card)), 0);
    s.tricks[t]++;
    s.lastTrick = { cards: s.trick, winner: w };
    s.trick = []; s.pending = null;
    if (s.hands[0].length === 0) {
      s.counters[t] += 1; // last trick
      this.scoreHand();
    } else s.turn = w;
  }

  scoreHand() {
    const s = this.s, dt = team(s.declarer);
    const meldT = [0, 1].map((t) => s.meld.reduce((a, m, i) => a + (team(i) === t ? m.total : 0), 0));
    const parts = [0, 1].map((t) => {
      const took = s.tricks[t] > 0;
      return { meld: meldT[t], counters: s.counters[t], took, base: took ? meldT[t] + s.counters[t] : 0, delta: 0 };
    });
    const made = parts[dt].base >= s.high;
    parts[dt].delta = made ? parts[dt].base : -s.high;
    parts[1 - dt].delta = parts[1 - dt].base;
    parts.forEach((p, t) => (s.scores[t] += p.delta));
    s.result = { bid: s.high, declarer: s.declarer, dteam: dt, made, parts };
    const reached = [0, 1].filter((t) => s.scores[t] >= TARGET);
    s.ready = [false, false, false, false];
    if (reached.length) {
      s.winner = reached.length === 2 ? dt : reached[0];
      s.phase = 'over';
    } else s.phase = 'hand';
    s.turn = -1;
  }

  viewFor(seat) {
    const s = this.s;
    const v = JSON.parse(JSON.stringify(s));
    v.counts = s.hands.map((h) => h.length);
    v.hand = s.hands[seat].slice();
    delete v.hands;
    v.me = seat;
    v.legal = s.phase === 'play' && s.turn === seat && !s.pending ? this.legal(seat) : [];
    v.minBid = Math.max(MIN_BID, s.high + 1);
    v.target = TARGET;
    return v;
  }
}

// ---------- bots ----------
function bestSplit(ids, n, score) {
  // choose n cards to remove from ids maximising score(removed, remaining)
  let best = null, bv = -Infinity;
  const pick = (start, chosen) => {
    if (chosen.length === n) {
      const rem = ids.filter((i) => !chosen.includes(i));
      const v = score(chosen, rem);
      if (v > bv) { bv = v; best = chosen.slice(); }
      return;
    }
    for (let i = start; i < ids.length; i++) { chosen.push(ids[i]); pick(i + 1, chosen); chosen.pop(); }
  };
  pick(0, []);
  return best;
}
const EST_BASE = 20;
const worth = (c, trump) => (c.s === trump ? 10 : 0) + c.r;

export function botAction(game, seat) {
  const s = game.s;
  const hand = s.hands[seat];
  switch (s.phase) {
    case 'bid': {
      if (game._max[seat] == null) {
        let best = 0;
        for (let t = 0; t < 4; t++) {
          const len = hand.filter((i) => card(i).s === t).length;
          best = Math.max(best, meldOf(hand, t).total + 2 * (len - 3));
        }
        game._max[seat] = best + EST_BASE + ((Math.random() * 7) | 0) - 3;
      }
      const max = Math.min(MAX_BID, game._max[seat]);
      const min = Math.max(MIN_BID, s.high + 1);
      if (max >= min) return { type: 'bid', amount: s.high < MIN_BID ? MIN_BID : Math.min(max, s.high + (max - s.high > 8 ? 2 : 1)) | 0 };
      return { type: 'pass' };
    }
    case 'trump': {
      let bt = 0, bv = -1;
      for (let t = 0; t < 4; t++) {
        const tr = hand.map(card).filter((c) => c.s === t);
        const v = meldOf(hand, t).total + 1.5 * tr.length + tr.filter((c) => c.r >= 4).length * 1.5;
        if (v > bv) { bv = v; bt = t; }
      }
      return { type: 'trump', suit: bt };
    }
    case 'give1': // partner sends strong cards to declarer, keeping its own meld
      return { type: 'give', cards: bestSplit(hand, 3, (given, rem) =>
        given.reduce((a, i) => a + worth(card(i), s.trump), 0) * 0.5 + meldOf(rem, s.trump).total) };
    case 'give2': // declarer returns the weakest cards
      return { type: 'give', cards: bestSplit(hand, 3, (given, rem) =>
        meldOf(rem, s.trump).total + rem.reduce((a, i) => a + worth(card(i), s.trump), 0) * 0.3) };
    case 'play':
      return { type: 'play', card: botPlay(game, seat) };
    case 'meld': case 'hand': case 'over':
      return { type: 'ready' };
  }
  return null;
}

function botPlay(game, seat) {
  const s = game.s, trump = s.trump;
  const hand = s.hands[seat].map(card);
  const trick = game.tcards();
  const legal = legalPlays(hand, trick, trump);
  const byLow = (a, b) => worth(a, trump) - worth(b, trump);
  if (legal.length === 1) return legal[0].id;
  if (!trick.length) {
    const mine = team(seat) === team(s.declarer);
    const tr = legal.filter((c) => c.s === trump).sort((a, b) => b.r - a.r);
    const off = legal.filter((c) => c.s !== trump);
    if (mine && tr.length >= 2 && tr[0].r >= 4) return tr[0].id; // draw trump
    const aces = off.filter((c) => c.r === 5);
    if (aces.length) return aces[0].id;
    if (off.length) return off.sort(byLow)[0].id;
    return tr.sort(byLow)[0].id;
  }
  const bestSeat = winnerOf(trick, trump);
  const bestCard = trick.find((t) => t.seat === bestSeat).card;
  const partnerWins = team(bestSeat) === team(seat);
  const wins = legal.filter((c) => beats(c, bestCard, trump));
  if (partnerWins) {
    const smear = legal.filter((c) => pts(c) && c.s !== trump).sort(byLow);
    if (smear.length) return smear[smear.length - 1].id;
    return legal.slice().sort((a, b) => pts(a) - pts(b) || byLow(a, b))[0].id;
  }
  if (wins.length) return wins.sort(byLow)[0].id;
  return legal.slice().sort((a, b) => pts(a) - pts(b) || byLow(a, b))[0].id;
}

// ---------- table: game + seats + bot/turn timers ----------
export class Table {
  // seats: [{name, human, connected}] — non-humans or disconnected humans are played by bots.
  constructor(seats, onChange, speed = 1) {
    this.seats = seats;
    this.onChange = onChange || (() => {});
    this.speed = speed;
    this.game = new Game();
    this.timer = null;
    this.schedule();
  }
  auto(seat) {
    const x = this.seats[seat];
    return !x.human || !x.connected;
  }
  act(seat, a) {
    const r = this.game.act(seat, a);
    if (r.ok) this.changed();
    return r;
  }
  changed() {
    this.onChange(this);
    this.schedule();
  }
  stop() { clearTimeout(this.timer); this.timer = null; }
  schedule() {
    clearTimeout(this.timer);
    const g = this.game, s = g.s, k = this.speed;
    const later = (ms, fn) => { this.timer = setTimeout(fn, ms * k); };
    if (s.pending === 'trick') return later(1500, () => { g.resolveTrick(); this.changed(); });
    if (['meld', 'hand', 'over'].includes(s.phase)) {
      const todo = [0, 1, 2, 3].filter((i) => this.auto(i) && !s.ready[i]);
      if (todo.length) later(s.phase === 'meld' ? 1500 : 1200, () => {
        for (const i of todo) g.act(i, { type: 'ready' });
        this.changed();
      });
      return;
    }
    if (s.turn >= 0 && this.auto(s.turn)) {
      later(s.phase === 'play' ? 800 : 1000, () => {
        const a = botAction(g, s.turn);
        const r = g.act(s.turn, a);
        if (!r.ok) console.error('bot error', r.err, a);
        this.changed();
      });
    }
  }
  setConnected(seat, on) {
    this.seats[seat].connected = on;
    this.schedule();
  }
  viewFor(seat) {
    const v = this.game.viewFor(seat);
    v.seats = this.seats.map((x) => ({ name: x.name, human: x.human, connected: x.connected }));
    return v;
  }
}

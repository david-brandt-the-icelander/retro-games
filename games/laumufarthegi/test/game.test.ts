// The rules (shared/game.ts): who sees what, turns, votes, points, timeouts and topics.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { act, addPlayer, newRoom, setConnected, tick, view, HOST_GRACE_MS, type State, type Topic } from "../shared/game";
import { TOPICS } from "../shared/topics";

const WORDS = (p: string) => Array.from({ length: 16 }, (_, i) => `${p}${i}`);
const T: Topic[] = [
  { efni: "Létt barnvænt", ord: WORDS("a"), barnvaent: true, erfidleiki: 1 },
  { efni: "Miðlungs", ord: WORDS("b"), barnvaent: false, erfidleiki: 2 },
  { efni: "Erfitt", ord: WORDS("c"), barnvaent: true, erfidleiki: 3 },
];

/** A seeded generator, so every test plays the same game. */
function seeded(seed: number): () => number {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** A room with players p0 (host) … p{n-1}, all connected. */
function room(n: number, now = 1000): State {
  const s = newRoom("ABCDE", { id: "p0", name: "Anna", token: "t0" }, now);
  setConnected(s, "p0", true, now);
  const names = ["Anna", "Bjarni", "Dísa", "Einar", "Fríða", "Gunnar", "Hildur", "Ívar", "Jóna", "Kári"];
  for (let i = 1; i < n; i++) {
    assert.ok(addPlayer(s, names[i], `p${i}`, `t${i}`, now).ok);
    setConnected(s, `p${i}`, true, now);
  }
  return s;
}

function started(n: number, seed = 1): State {
  const s = room(n);
  assert.deepEqual(act(s, "p0", { t: "start" }, 1000, T, seeded(seed)), { ok: true });
  return s;
}

/** Plays every clue turn with a harmless clue. */
function allClues(s: State, now = 2000): void {
  const r = s.round!;
  while (s.phase === "clues") assert.ok(act(s, r.order[r.turn], { t: "clue", text: "vísbending" }, now, T, Math.random).ok);
}

test("a game needs three connected players, and only the host starts it", () => {
  const s = room(2);
  assert.equal(act(s, "p0", { t: "start" }, 1000, T, Math.random).ok, false);
  const s3 = room(3);
  assert.equal(act(s3, "p1", { t: "start" }, 1000, T, Math.random).ok, false);
  setConnected(s3, "p2", false, 1000);
  assert.equal(act(s3, "p0", { t: "start" }, 1000, T, Math.random).ok, false, "a player who is away doesn't count");
});

test("starting deals a topic, a secret word, a stowaway and the clue order", () => {
  const s = started(5);
  const r = s.round!;
  assert.equal(s.phase, "clues");
  assert.deepEqual([...r.order].sort(), ["p0", "p1", "p2", "p3", "p4"]);
  assert.ok(r.order.includes(r.stowaway));
  assert.ok(r.secret >= 0 && r.secret < 16);
  assert.equal(r.deadline, 1000 + s.settings.clueSeconds * 1000);
});

test("only the players who should know it see the secret word, and nobody sees the stowaway before the reveal", () => {
  const s = started(5, 7);
  const r = s.round!;
  for (const p of s.players) {
    const v = view(s, p.id, T, 1500);
    const text = JSON.stringify(v);
    assert.equal(v.round!.reveal, null);
    assert.equal(v.round!.accused, null);
    if (p.id === r.stowaway) {
      assert.equal(v.round!.secret, null);
      assert.equal(v.me.stowaway, true);
    } else {
      assert.equal(v.round!.secret, r.secret);
      assert.equal(v.me.stowaway, false);
      assert.ok(!text.includes('"stowaway":"'), "no view names the stowaway");
    }
  }
  allClues(s);
  for (const p of s.players) assert.equal(view(s, p.id, T, 2500).round!.reveal, null, "still hidden while voting");
});

test("a player who joins during a round waits for the next one and sees no secret", () => {
  const s = started(3);
  assert.ok(addPlayer(s, "Seinn", "late", "tl", 1100).ok);
  setConnected(s, "late", true, 1100);
  const v = view(s, "late", T, 1200);
  assert.equal(v.me.inRound, false);
  assert.equal(v.round!.secret, null);
  allClues(s);
  assert.equal(act(s, "late", { t: "vote", target: "p0" }, 2100, T, Math.random).ok, false);
});

test("clues go in turn; the secret word itself is refused, except from the stowaway who can't know it", () => {
  const s = started(4, 3);
  const r = s.round!;
  const notTurn = r.order[1];
  assert.equal(act(s, notTurn, { t: "clue", text: "of snemmt" }, 1100, T, Math.random).ok, false);
  const first = r.order[0];
  const secretWord = T[r.topic].ord[r.secret];
  const res = act(s, first, { t: "clue", text: ` ${secretWord.toUpperCase()} ` }, 1100, T, Math.random);
  if (first === r.stowaway) assert.ok(res.ok);
  else {
    assert.equal(res.ok, false);
    assert.ok(act(s, first, { t: "clue", text: "  langt   orð  " }, 1100, T, Math.random).ok);
    assert.equal(r.clues[0].text, "langt orð");
  }
  assert.equal(r.turn, 1);
  assert.equal(r.deadline, 1100 + s.settings.clueSeconds * 1000, "each turn gets its own time");
});

test("a turn that runs out counts as an empty clue; the vote and the guess time out too", () => {
  const s = started(3, 5);
  const r = s.round!;
  assert.equal(tick(s, r.deadline! - 1), false);
  assert.equal(tick(s, r.deadline!), true);
  assert.equal(r.clues[0].text, "—");
  while (s.phase === "clues") tick(s, r.deadline!);
  assert.equal(s.phase, "voting");
  tick(s, r.deadline!);
  assert.equal(s.phase, "reveal", "nobody voted: a tie, the stowaway escapes");
  assert.equal(r.points[r.stowaway], 3);
});

test("votes: not for yourself, may be changed, and the vote closes when everyone has voted", () => {
  const s = started(4, 9);
  allClues(s);
  const [a, b, c, d] = s.round!.order;
  assert.equal(act(s, a, { t: "vote", target: a }, 3000, T, Math.random).ok, false);
  assert.ok(act(s, a, { t: "vote", target: b }, 3000, T, Math.random).ok);
  assert.ok(act(s, a, { t: "vote", target: c }, 3000, T, Math.random).ok);
  assert.equal(s.round!.votes[a], c);
  assert.equal(view(s, b, T, 3000).players.find((p) => p.id === a)!.voted, true, "others see that a has voted, not for whom");
  assert.equal(view(s, b, T, 3000).round!.myVote, null);
  act(s, b, { t: "vote", target: c }, 3000, T, Math.random);
  act(s, c, { t: "vote", target: d }, 3000, T, Math.random);
  assert.equal(s.phase, "voting");
  act(s, d, { t: "vote", target: c }, 3000, T, Math.random);
  assert.notEqual(s.phase, "voting");
  assert.equal(s.round!.accused, c);
});

/** Plays a round where everyone votes as `votesFor(voter)` says. */
function playVotes(s: State, votesFor: (voter: string, stowaway: string, order: string[]) => string): void {
  allClues(s);
  const r = s.round!;
  for (const id of r.order) act(s, id, { t: "vote", target: votesFor(id, r.stowaway, r.order) }, 3000, T, Math.random);
}

test("points: caught and guessing wrong gives every other player 1, plus 1 for each right vote", () => {
  const s = started(4, 11);
  playVotes(s, (voter, stow, order) => (voter === stow ? order.find((x) => x !== stow)! : stow));
  const r = s.round!;
  assert.equal(s.phase, "guess");
  assert.equal(view(s, r.order.find((x) => x !== r.stowaway)!, T, 3000).round!.accused, r.stowaway, "everyone learns who was caught");
  assert.equal(act(s, r.order.find((x) => x !== r.stowaway)!, { t: "guess", index: 0 }, 3100, T, Math.random).ok, false);
  act(s, r.stowaway, { t: "guess", index: (r.secret + 1) % 16 }, 3100, T, Math.random);
  assert.equal(s.phase, "reveal");
  for (const id of r.order) assert.equal(r.points[id], id === r.stowaway ? 0 : 2);
  assert.equal(s.players.find((p) => p.id === r.stowaway)!.score, 0);
});

test("points: caught but guessing the word gives the stowaway 1", () => {
  const s = started(4, 12);
  playVotes(s, (voter, stow, order) => (voter === stow ? order.find((x) => x !== stow)! : stow));
  const r = s.round!;
  act(s, r.stowaway, { t: "guess", index: r.secret }, 3100, T, Math.random);
  // The stowaway gets 1 for the word; everyone else gets 1 for voting right and nothing more.
  for (const id of r.order) assert.equal(r.points[id], 1);
});

test("points: a wrong accusation or a tie lets the stowaway escape with 3", () => {
  const s = started(4, 13);
  // Everyone accuses the same innocent player (who votes for someone else innocent).
  playVotes(s, (voter, stow, order) => {
    const innocent = order.filter((x) => x !== stow);
    return voter === innocent[0] ? innocent[1] : innocent[0];
  });
  const r = s.round!;
  assert.equal(s.phase, "reveal");
  assert.notEqual(r.accused, r.stowaway);
  assert.equal(r.points[r.stowaway], 3);
  for (const id of r.order) if (id !== r.stowaway) assert.equal(r.points[id], 0);

  const t = started(4, 14);
  playVotes(t, (voter, stow, order) => order[(order.indexOf(voter) + 1) % order.length]); // one vote each: a tie
  assert.equal(t.round!.accused, null);
  assert.equal(t.round!.points[t.round!.stowaway], 3);
});

test("the game runs its rounds, then ends; a new game resets the scores", () => {
  const s = room(3);
  act(s, "p0", { t: "settings", settings: { rounds: 2 } }, 1000, T, Math.random);
  act(s, "p0", { t: "start" }, 1000, T, seeded(2));
  for (let round = 1; round <= 2; round++) {
    playVotes(s, (voter, stow, order) => order[(order.indexOf(voter) + 1) % order.length]);
    assert.equal(s.phase, "reveal");
    assert.equal(act(s, "p1", { t: "next" }, 4000, T, Math.random).ok, false, "only the host moves on");
    act(s, "p0", { t: "next" }, 4000, T, seeded(round));
  }
  assert.equal(s.phase, "over");
  assert.ok(s.players.some((p) => p.score > 0));
  act(s, "p0", { t: "start" }, 5000, T, seeded(3));
  assert.equal(s.phase, "clues");
  assert.ok(s.players.every((p) => p.score === 0));
});

test("topics: none repeats until all that fit are used, and the host's filters hold", () => {
  const s = room(3);
  act(s, "p0", { t: "settings", settings: { maxDifficulty: 3, childOnly: true, rounds: 20 } }, 1000, T, Math.random);
  const seen: number[] = [];
  act(s, "p0", { t: "start" }, 1000, T, seeded(4));
  for (let i = 0; i < 4; i++) {
    seen.push(s.round!.topic);
    assert.ok(T[s.round!.topic].barnvaent);
    playVotes(s, (voter, stow, order) => order[(order.indexOf(voter) + 1) % order.length]);
    act(s, "p0", { t: "next" }, 4000, T, seeded(10 + i));
  }
  assert.deepEqual([...new Set(seen.slice(0, 2))].sort(), [0, 2], "both child-friendly topics before any repeats");
  assert.ok(seen.slice(2).every((i) => i === 0 || i === 2));

  const e = room(3);
  act(e, "p0", { t: "settings", settings: { maxDifficulty: 1 } }, 1000, T, Math.random);
  act(e, "p0", { t: "start" }, 1000, T, seeded(5));
  assert.equal(e.round!.topic, 0);
});

test("settings: host only, between games, and kept in range", () => {
  const s = room(3);
  assert.equal(act(s, "p1", { t: "settings", settings: { rounds: 3 } }, 1000, T, Math.random).ok, false);
  act(s, "p0", { t: "settings", settings: { rounds: 99, clueSeconds: 1, voteSeconds: -5, maxDifficulty: 7 } }, 1000, T, Math.random);
  assert.deepEqual(s.settings, { rounds: 20, clueSeconds: 15, voteSeconds: 20, maxDifficulty: 3, childOnly: false });
  act(s, "p0", { t: "start" }, 1000, T, seeded(1));
  assert.equal(act(s, "p0", { t: "settings", settings: { rounds: 3 } }, 1000, T, Math.random).ok, false);
});

test("another player may take over once the host has been away for a while", () => {
  const s = room(3);
  setConnected(s, "p0", false, 10_000);
  assert.equal(view(s, "p1", T, 10_000 + HOST_GRACE_MS - 1).canClaimHost, false);
  assert.equal(act(s, "p1", { t: "claimHost" }, 10_000 + HOST_GRACE_MS - 1, T, Math.random).ok, false);
  assert.equal(view(s, "p1", T, 10_000 + HOST_GRACE_MS).canClaimHost, true);
  assert.ok(act(s, "p1", { t: "claimHost" }, 10_000 + HOST_GRACE_MS, T, Math.random).ok);
  assert.equal(s.hostId, "p1");
});

test("the host may remove a player, but not one who is playing the current round", () => {
  const s = started(4);
  const r = s.round!;
  const victim = r.order.find((x) => x !== "p0")!;
  assert.equal(act(s, "p0", { t: "kick", player: victim }, 1100, T, Math.random).ok, false);
  playVotes(s, (voter, stow, order) => order[(order.indexOf(voter) + 1) % order.length]);
  assert.ok(act(s, "p0", { t: "kick", player: victim }, 4000, T, Math.random).ok);
  assert.ok(!s.players.some((p) => p.id === victim));
  assert.equal(act(s, "p1", { t: "kick", player: "p0" }, 4000, T, Math.random).ok, false);
});

test("names: required, unique (ignoring case), trimmed, and the room holds ten", () => {
  const s = room(1);
  assert.equal(addPlayer(s, "   ", "x", "tx", 1).ok, false);
  assert.equal(addPlayer(s, "anna", "x", "tx", 1).ok, false);
  assert.ok(addPlayer(s, "  Bjarni   Þór ", "b", "tb", 1).ok);
  assert.equal(s.players[1].name, "Bjarni Þór");
  for (let i = 0; i < 8; i++) addPlayer(s, `L${i}`, `l${i}`, `tl${i}`, 1);
  assert.equal(s.players.length, 10);
  assert.equal(addPlayer(s, "Ellefti", "e", "te", 1).ok, false);
});

test("the real topic list: every topic has 16 different words and a difficulty", () => {
  assert.ok(TOPICS.length >= 100);
  for (const t of TOPICS) {
    assert.equal(new Set(t.ord).size, 16, t.efni);
    assert.ok([1, 2, 3].includes(t.erfidleiki), t.efni);
  }
  assert.ok(TOPICS.filter((t) => t.barnvaent && t.erfidleiki === 1).length >= 20, "enough easy child-friendly topics");
});

// Static file server + WebSocket rooms for online pinochle.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';
import { Table } from '../public/engine.js';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'public');
const PORT = process.env.PORT || 3000;
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css',
  '.json': 'application/json', '.webmanifest': 'application/manifest+json', '.svg': 'image/svg+xml',
  '.png': 'image/png',
};

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const file = path.normalize(path.join(ROOT, p));
  if (!file.startsWith(ROOT)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404).end('not found'); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    res.end(data);
  });
});

// ---- rooms ----
const rooms = new Map(); // code -> room
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const newCode = () => {
  for (;;) {
    const c = Array.from({ length: 4 }, () => CODE_CHARS[(Math.random() * CODE_CHARS.length) | 0]).join('');
    if (!rooms.has(c)) return c;
  }
};
const clean = (s) => String(s || '').replace(/[^\p{L}\p{N} _.-]/gu, '').trim().slice(0, 14) || 'Player';
const BOT_NAMES = ['Ava', 'Max', 'Zoe', 'Leo', 'Ivy', 'Sam'];

function send(ws, msg) { if (ws && ws.readyState === 1) ws.send(JSON.stringify(msg)); }

function roomState(room, seat) {
  return {
    t: 'room', code: room.code, you: seat, host: room.host, started: !!room.table,
    seats: room.seats.map((x) => x && { name: x.name, connected: x.connected }),
    view: room.table ? room.table.viewFor(seat) : null,
  };
}
function broadcast(room) {
  room.seats.forEach((x, i) => { if (x && x.ws) send(x.ws, roomState(room, i)); });
}

function seatOf(room, ws) { return room.seats.findIndex((x) => x && x.ws === ws); }

function startGame(room) {
  const bots = [...BOT_NAMES].sort(() => Math.random() - 0.5);
  const seats = room.seats.map((x, i) => x
    ? { name: x.name, human: true, connected: x.connected }
    : { name: bots.pop(), human: false, connected: true });
  room.table = new Table(seats, () => broadcast(room), Number(process.env.SPEED) || 1);
  room.table.changed();
}

wss_setup();
function wss_setup() {
  const wss = new WebSocketServer({ server, path: '/ws' });
  wss.on('connection', (ws) => {
    ws.alive = true;
    ws.on('pong', () => { ws.alive = true; });
    ws.on('message', (raw) => {
      let m;
      try { m = JSON.parse(raw); } catch { return; }
      handle(ws, m);
    });
    ws.on('close', () => {
      const room = ws.room;
      if (!room) return;
      const i = seatOf(room, ws);
      if (i < 0) return;
      const x = room.seats[i];
      x.ws = null; x.connected = false;
      if (room.table) room.table.setConnected(i, false);
      else if (!room.started) room.seats[i] = null; // leave the lobby seat
      if (!room.seats.some((s) => s && s.connected)) room.emptySince = Date.now();
      if (room.host === i) room.host = room.seats.findIndex((s) => s && s.connected);
      broadcast(room);
    });
  });
  setInterval(() => {
    for (const ws of wss.clients) {
      if (!ws.alive) { ws.terminate(); continue; }
      ws.alive = false; ws.ping();
    }
    for (const [code, r] of rooms) {
      if (r.emptySince && Date.now() - r.emptySince > 30 * 60 * 1000) { r.table?.stop(); rooms.delete(code); }
    }
  }, 30000);
}

function attach(room, ws, seat, name, token) {
  const old = room.seats[seat];
  if (old && old.ws && old.ws !== ws) { old.ws.room = null; send(old.ws, { t: 'kicked' }); }
  room.seats[seat] = { name, token, ws, connected: true };
  ws.room = room;
  room.emptySince = null;
  if (room.table) {
    room.table.seats[seat].connected = true;
    room.table.seats[seat].name = name;
    room.table.schedule();
  }
}

function handle(ws, m) {
  const room = ws.room;
  switch (m.t) {
    case 'create': {
      const code = newCode();
      const r = { code, seats: [null, null, null, null], host: 0, table: null, emptySince: null };
      rooms.set(code, r);
      attach(r, ws, 0, clean(m.name), String(m.token || ''));
      broadcast(r);
      return;
    }
    case 'join': {
      const r = rooms.get(String(m.code || '').toUpperCase().trim());
      if (!r) return send(ws, { t: 'error', msg: 'No game with that code.' });
      const token = String(m.token || '');
      let seat = token ? r.seats.findIndex((x) => x && x.token === token) : -1;
      if (seat < 0) {
        if (r.table) return send(ws, { t: 'error', msg: 'That game has already started.' });
        seat = r.seats.findIndex((x) => !x);
        if (seat < 0) return send(ws, { t: 'error', msg: 'That game is full.' });
      }
      attach(r, ws, seat, clean(m.name), token);
      if (r.host < 0 || !r.seats[r.host]) r.host = seat;
      broadcast(r);
      return;
    }
    case 'sit': { // choose your seat in the lobby (partners sit opposite)
      if (!room || room.table) return;
      const from = seatOf(room, ws), to = m.seat | 0;
      if (from < 0 || to < 0 || to > 3 || room.seats[to]) return;
      room.seats[to] = room.seats[from]; room.seats[from] = null;
      if (room.host === from) room.host = to;
      broadcast(room);
      return;
    }
    case 'start': {
      if (!room || room.table || seatOf(room, ws) !== room.host) return;
      startGame(room);
      return;
    }
    case 'act': {
      if (!room || !room.table) return;
      const seat = seatOf(room, ws);
      if (seat < 0) return;
      const r = room.table.act(seat, m.action);
      if (!r.ok) send(ws, { t: 'error', msg: r.err });
      return;
    }
    case 'leave': {
      if (!room) return;
      const i = seatOf(room, ws);
      ws.room = null;
      if (i >= 0) {
        const x = room.seats[i];
        x.ws = null; x.connected = false;
        if (room.table) { x.token = ''; room.table.setConnected(i, false); }
        else room.seats[i] = null;
        if (room.host === i) room.host = room.seats.findIndex((s) => s && s.connected);
        if (!room.seats.some((s) => s && s.connected)) room.emptySince = Date.now();
        broadcast(room);
      }
      return;
    }
  }
}

server.listen(PORT, () => console.log(`Pinochle running at http://localhost:${PORT}`));

// Checks the calendar in headless Chrome and saves screenshots:
//   node art/snap.mjs [OUT_DIR]   (default: advent-snaps in the system temp folder)
// house-phone.png, house-desktop.png: the house at phone and desktop sizes.
// sheet-*.png: all 24 windows at a few moments. flow-*.png: one window
// peeling open, playing, closing, and opening again. Fails on page errors.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chrome, serve, sleep } from './chrome.mjs';

const game = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.resolve(process.argv[2] || path.join(os.tmpdir(), 'advent-snaps'));
fs.mkdirSync(out, { recursive: true });
const server = await serve(game), browser = await chrome();
const errors = [];
const log = m => console.log(new Date().toISOString().slice(11, 19), m);
const check = (name, page) => { const bad = page.logs.filter(l => /^(error|exception)/.test(l)); if (bad.length) errors.push(name + ':\n  ' + bad.join('\n  ')); };
const until = async (page, expr, ms = 8000) => { for (let t = 0; t < ms; t += 100) { if (await page.eval(expr)) return; await sleep(100); } throw new Error('timed out waiting for ' + expr); };

try {
  // the house, phone and desktop
  const phone = await browser.page(server.url + '/index.html', { width: 390, height: 844, dpr: 3, mobile: true });
  await sleep(800);
  const h = await phone.eval('document.getElementById("stage").getBoundingClientRect().height');
  await phone.shot(path.join(out, 'house-phone.png'), { x: 0, y: 0, width: 390, height: Math.ceil(h) });
  const desk = await browser.page(server.url + '/index.html', { width: 1280, height: 900, dpr: 1 });
  await sleep(800);
  await desk.shot(path.join(out, 'house-desktop.png'));
  check('house', phone); check('house desktop', desk);

  log('houses done');
  // the open, close and re-open flow on the phone: tap window 1
  await desk.close();
  const r = await phone.eval('(()=>{const b=document.querySelector(\'.win[data-d="1"]\').getBoundingClientRect();return {x:b.left+b.width/2,y:b.top+b.height/2,top:b.top}})()');
  await phone.eval(`scrollTo(0, ${Math.max(0, r.top - 300)})`);
  await sleep(200);
  const r2 = await phone.eval('(()=>{const b=document.querySelector(\'.win[data-d="1"]\').getBoundingClientRect();return {x:b.left+b.width/2,y:b.top+b.height/2}})()');
  await phone.tap(r2.x, r2.y);
  for (const ms of [180, 420]) { await sleep(ms === 180 ? 180 : 240); await phone.shot(path.join(out, `flow-1-peel-${ms}ms.png`)); }
  await until(phone, 'advent.viewer.started');
  for (const s of [0.6, 1.6, 3.2, 6]) { await sleep(s * 1000 - (await phone.eval('(performance.now()-advent.viewer.t0)'))); await phone.shot(path.join(out, `flow-2-play-${s}s.png`)); }
  const c = await phone.eval('(()=>{const b=document.getElementById("card").getBoundingClientRect();return {x:b.left+b.width/2,y:b.top+b.height/2}})()');
  await phone.tap(c.x, c.y);
  await sleep(700); await phone.shot(path.join(out, 'flow-3-closing.png'));
  await until(phone, '!advent.viewer.busy && !advent.viewer.on');
  await sleep(200); await phone.shot(path.join(out, 'flow-4-closed.png'));
  const state1 = await phone.eval('({seen: JSON.parse(localStorage.getItem("adv2-seen")), cls: document.querySelector(\'.win[data-d="1"]\').className})');
  await phone.tap(r2.x, r2.y);
  await until(phone, 'advent.viewer.started');
  await sleep(1500); await phone.shot(path.join(out, 'flow-5-reopened.png'));
  const state2 = await phone.eval('({on: advent.viewer.on, d: advent.viewer.d, t: (performance.now()-advent.viewer.t0)/1000})');
  console.log('after close:', JSON.stringify(state1), ' reopened:', JSON.stringify(state2));
  check('flow', phone);

  log('flow done');
  // contact sheets: every window at a few moments
  const sh = await browser.page(server.url + '/index.html?sheet=0.6,2,3.5,6', { width: 1620, height: 900, dpr: 1 });
  await until(sh, 'window.sheetDone', 30000);
  const H = await sh.eval('document.querySelector("canvas[style]").getBoundingClientRect().height');
  for (let j = 0; j < 4; j++) await sh.shot(path.join(out, `sheet-${['0.6', '2', '3.5', '6'][j]}s.png`), { x: 0, y: j * H / 4, width: 810, height: H / 4 });
  check('sheet', sh);

  log('sheets done');
  // a big desktop view of one held moment, and reduced motion
  const one = await browser.page(server.url + '/index.html?open=8&t=2.45', { width: 1280, height: 900, dpr: 1 });
  await sleep(2200); await one.shot(path.join(out, 'desktop-open-8.png')); check('open 8', one);
  const rm = await browser.page(server.url + '/index.html', { width: 390, height: 844, dpr: 2, mobile: true, reducedMotion: true });
  await sleep(500); await rm.eval('advent.open(24)'); await sleep(900); await rm.shot(path.join(out, 'reduced-motion-24.png')); check('reduced motion', rm);
} finally {
  await browser.close(); server.close();
}
if (errors.length) { console.error('page errors:\n' + errors.join('\n')); process.exit(1); }
console.log('ok, screenshots in ' + out);

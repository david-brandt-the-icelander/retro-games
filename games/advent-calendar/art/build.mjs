// Renders all the art into ../assets/: WebP images and sprite atlases, and
// art.js, the manifest the game reads (sprite rectangles and pivots, light
// and window positions). Needs Node 22+ and Chrome; installs nothing.
//
//   node art/build.mjs            every sheet
//   node art/build.mjs house sp-fox   only those sheets (the manifest keeps the rest)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chrome, serve, sleep } from './chrome.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const game = path.resolve(here, '..'), out = path.join(game, 'assets');
fs.mkdirSync(out, { recursive: true });

const manifestFile = path.join(out, 'art.js');
const prefix = 'window.ADVENT_ART=';
let manifest = {};
if (fs.existsSync(manifestFile)) manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8').slice(prefix.length).replace(/;\s*$/, ''));

const server = await serve(game), browser = await chrome();
try {
  const page = await browser.page(`${server.url}/art/render.html`, { width: 800, height: 600, dpr: 1 });
  for (let i = 0; i < 50 && !(await page.eval('!!window.ready')); i++) await sleep(100);
  const names = await page.eval('sheetNames()');
  const want = process.argv.slice(2);
  const todo = want.length ? names.filter(n => want.some(w => n === w || n.startsWith(w + '-') || (w.endsWith('*') && n.startsWith(w.slice(0, -1))))) : names;
  if (want.length && !todo.length) throw new Error('No sheet matches ' + want.join(' ') + '. Sheets: ' + names.join(' '));
  let total = 0;
  for (const name of todo) {
    const t0 = Date.now();
    const r = await page.eval(`renderSheet(${JSON.stringify(name)})`);
    const buf = Buffer.from(r.data.split(',')[1], 'base64');
    fs.writeFileSync(path.join(out, r.file), buf);
    manifest[name] = { file: r.file, ...r.meta };
    total += buf.length;
    console.log(`${name.padEnd(14)} ${r.file.padEnd(16)} ${(buf.length / 1024).toFixed(0).padStart(5)} KB  ${Date.now() - t0} ms`);
  }
  if (page.logs.length) console.log(page.logs.join('\n'));
  const keep = Object.fromEntries(names.filter(n => manifest[n]).map(n => [n, manifest[n]]));
  fs.writeFileSync(manifestFile, prefix + JSON.stringify(keep) + ';\n');
  console.log(`wrote ${todo.length} sheets, ${(total / 1024).toFixed(0)} KB`);
} finally {
  await browser.close(); server.close();
}

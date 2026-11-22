// Drives headless Chrome over the DevTools protocol with nothing but Node's
// own modules: a static file server for the game folder, and a page you can
// evaluate script in, tap, and screenshot. Used by build.mjs and snap.mjs.
import { spawn } from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const TYPES = { '.html': 'text/html; charset=utf-8', '.mjs': 'text/javascript', '.js': 'text/javascript', '.json': 'application/json', '.webp': 'image/webp', '.png': 'image/png', '.svg': 'image/svg+xml' };

export async function serve(root) {
  root = path.resolve(root);
  const srv = http.createServer((q, r) => {
    let f = path.join(root, decodeURIComponent(new URL(q.url, 'http://x').pathname));
    if (!f.startsWith(root)) { r.writeHead(403); return r.end(); }
    if (fs.existsSync(f) && fs.statSync(f).isDirectory()) f = path.join(f, 'index.html');
    fs.readFile(f, (e, b) => {
      if (e) { r.writeHead(404); return r.end(); }
      r.writeHead(200, { 'content-type': TYPES[path.extname(f)] || 'application/octet-stream', 'cache-control': 'no-store' });
      r.end(b);
    });
  });
  await new Promise(res => srv.listen(0, '127.0.0.1', res));
  return { url: `http://127.0.0.1:${srv.address().port}`, close: () => srv.close() };
}

function chromePath() {
  const cands = [process.env.CHROME, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'].filter(Boolean);
  const found = cands.find(p => fs.existsSync(p));
  if (!found) throw new Error('Chrome not found: set CHROME to its executable');
  return found;
}

export async function chrome() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'advent-chrome-'));
  const proc = spawn(chromePath(), ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${dir}`,
    '--no-first-run', '--no-default-browser-check', '--hide-scrollbars', '--force-color-profile=srgb', 'about:blank']);
  const wsUrl = await new Promise((res, rej) => {
    let buf = '';
    proc.stderr.on('data', d => { buf += d; const m = buf.match(/DevTools listening on (ws:\S+)/); if (m) res(m[1]); });
    proc.on('exit', () => rej(new Error('Chrome exited:\n' + buf)));
  });
  const sock = new WebSocket(wsUrl);
  await new Promise((res, rej) => { sock.onopen = res; sock.onerror = rej; });
  let id = 0; const pending = new Map(), listeners = new Set();
  sock.onmessage = e => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.rej(new Error(m.error.message)) : p.res(m.result); }
    else listeners.forEach(fn => fn(m));
  };
  const send = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const i = ++id;
    const timer = setTimeout(() => { pending.delete(i); rej(new Error(method + ' timed out')); }, 60000);
    pending.set(i, { res: v => { clearTimeout(timer); res(v); }, rej: e => { clearTimeout(timer); rej(e); } });
    sock.send(JSON.stringify({ id: i, method, params, sessionId }));
  });
  const waitFor = (sessionId, method) => new Promise(res => {
    const fn = m => { if (m.sessionId === sessionId && m.method === method) { listeners.delete(fn); res(m.params); } };
    listeners.add(fn);
  });

  async function page(url, { width = 390, height = 844, dpr = 2, mobile = false, reducedMotion = false } = {}) {
    const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
    const s = (m, p) => send(m, p, sessionId);
    const logs = [];
    listeners.add(m => {
      if (m.sessionId !== sessionId) return;
      if (m.method === 'Runtime.consoleAPICalled') logs.push(m.params.type + ': ' + m.params.args.map(a => a.value ?? a.description).join(' '));
      if (m.method === 'Runtime.exceptionThrown') logs.push('exception: ' + (m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text));
    });
    await s('Page.enable'); await s('Runtime.enable');
    await s('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: dpr, mobile });
    if (mobile) await s('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
    if (reducedMotion) await s('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
    const api = {
      logs,
      async goto(u) { const l = waitFor(sessionId, 'Page.loadEventFired'); await s('Page.navigate', { url: u }); await l; },
      async eval(expr) {
        const r = await s('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
        if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
        return r.result.value;
      },
      async shot(file, clip) {
        await s('Page.bringToFront');
        const r = await s('Page.captureScreenshot', { format: 'png', ...(clip ? { clip: { ...clip, scale: 1 }, captureBeyondViewport: true } : {}) });
        fs.writeFileSync(file, Buffer.from(r.data, 'base64'));
      },
      async tap(x, y) {
        await s('Page.bringToFront');
        if (mobile) {
          await s('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
          await s('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        } else {
          await s('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
          await s('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
          await s('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
        }
      },
      async move(x, y) { await s('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y }); },
      send: s,
      close: () => send('Target.closeTarget', { targetId }),
    };
    if (url) await api.goto(url);
    return api;
  }

  return {
    page,
    async close() {
      try { sock.close(); } catch { }
      const gone = new Promise(r => proc.once('exit', r));
      proc.kill(); await gone;
      fs.rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    },
  };
}

export const sleep = ms => new Promise(r => setTimeout(r, ms));

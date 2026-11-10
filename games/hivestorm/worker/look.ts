// The look of icelander.net, for Hivestorm's public high-score page: the site's header with the DHB
// monogram, a white page in Atlantic navy (deep ocean in dark mode), the page's text and table beside a
// quiet side panel, and the site's navy footer. Inline CSS and inline SVG only, so the strict CSP below
// holds; the Manrope font comes from icelander.net's own /fonts/ (font-src 'self'), with system fonts
// as the fallback.
export const escapeHtml = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

// The DHB monogram: a mirrored D and a B sharing the legs of an H.
const MARK_PATHS = `<path d="M48 22H40A24 38 0 0 0 40 98H48"/><path d="M48 22V98"/><path d="M72 22V98"/><path d="M72 22H80A24 38 0 0 1 103.6 53L98 60L103.6 67A24 38 0 0 1 80 98H72"/><path d="M48 60H98"/>`;
const mark = (cls = "mark") =>
  `<svg class="${cls}" viewBox="0 0 120 120" aria-hidden="true" focusable="false"><rect class="mark-bg" width="120" height="120" rx="26"/><g transform="translate(15 15) scale(0.75)" fill="none" stroke="#fff" stroke-width="12" stroke-linecap="round" stroke-linejoin="round">${MARK_PATHS}</g></svg>`;
const ICON = "data:image/svg+xml," + encodeURIComponent(
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120"><rect width="120" height="120" rx="26" fill="#0e2a47"/><g transform="translate(15 15) scale(0.75)" fill="none" stroke="#fff" stroke-width="13" stroke-linecap="round" stroke-linejoin="round">${MARK_PATHS}</g></svg>`);

const CSS = `
@font-face { font-family: Manrope; font-weight: 500; font-display: swap; src: url(/fonts/manrope-latin-500-normal.woff2) format("woff2"); }
@font-face { font-family: Manrope; font-weight: 700; font-display: swap; src: url(/fonts/manrope-latin-700-normal.woff2) format("woff2"); }
@font-face { font-family: "Source Serif 4"; font-weight: 400; font-display: swap; src: url(/fonts/source-serif-4-latin-400-normal.woff2) format("woff2"); }
@font-face { font-family: Manrope; font-weight: 800; font-display: swap; src: url(/fonts/manrope-latin-800-normal.woff2) format("woff2"); }
:root { color-scheme: light dark; --paper: #fff; --surface: #f4f6f8; --ink: #0e2a47; --text: #1d2b3a; --soft: #3a4b5d; --muted: #56677a;
  --line: #e3e8ed; --line-strong: #c5d0da; --accent: #b23a14; --btn-bg: #0e2a47; --btn-fg: #fff; --mark-bg: #0e2a47; --foot-bg: #0e2a47;
  --sans: Manrope, ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  --mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
@media (prefers-color-scheme: dark) {
  :root { --paper: #071726; --surface: #0b1f33; --ink: #e6f1f7; --text: #d3e0e9; --soft: #b5c6d2; --muted: #93abbb; --line: #1d3a52;
    --line-strong: #2d5070; --accent: #f0a07c; --btn-bg: #e6f1f7; --btn-fg: #0e2a47; --mark-bg: #1c3d5e; --foot-bg: #04101c; }
}
* { box-sizing: border-box; }
body { margin: 0; min-height: 100vh; display: flex; flex-direction: column; background: var(--paper); color: var(--text); font-family: var(--sans); font-size: 1rem; line-height: 1.6; }
a { color: var(--ink); }
a:hover { color: var(--accent); }
a:focus-visible, button:focus-visible, input:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; border-radius: 3px; }
.skip { position: absolute; left: -9999px; }
.skip:focus { left: 1rem; top: 1rem; background: var(--paper); padding: .6rem .9rem; border-radius: 8px; z-index: 10; }
.wrap { width: 100%; max-width: 75rem; margin-inline: auto; padding-inline: clamp(1.25rem, 4vw, 2rem); }
.mark { display: block; width: 2.25rem; height: 2.25rem; flex: none; }
.mark-bg { fill: var(--mark-bg); }
.on-dark .mark-bg { fill: #1c3d5e; }
.site-head { border-bottom: 1px solid var(--line); }
.head-row { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: .5rem 1.5rem; padding-block: .85rem; }
.brand { display: flex; align-items: center; gap: .75rem; min-height: 2.75rem; color: var(--ink); text-decoration: none; font-weight: 800; font-size: 1.1rem; }
.brand:hover { color: var(--ink); }
nav { display: flex; flex-wrap: wrap; align-items: center; gap: .1rem 1.5rem; font-size: .95rem; font-weight: 700; }
nav a:not(.btn) { color: var(--ink); text-decoration: none; padding-block: .75rem; }
nav a[aria-current] { text-decoration: underline; text-decoration-color: var(--accent); text-decoration-thickness: 2px; text-underline-offset: .5rem; }
.btn, .button { display: inline-flex; align-items: center; justify-content: center; width: fit-content; min-height: 2.75rem; padding: 0 1.15rem; border: 0;
  border-radius: 10px; background: var(--btn-bg); color: var(--btn-fg); font: inherit; font-size: .95rem; font-weight: 700; text-decoration: none; cursor: pointer; }
.btn:hover, .button:hover { color: var(--btn-fg); background: color-mix(in srgb, var(--btn-bg) 85%, var(--accent)); }
main.page { flex: 1; padding-block: clamp(2.5rem, 6vw, 4.5rem) clamp(3rem, 7vw, 6rem); }
.layout { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 2.5rem 3rem; }
.main { flex: 999 1 34rem; min-width: 0; overflow-x: auto; display: flex; flex-direction: column; gap: 2rem; }
.eyebrow { margin: 0 0 1rem; font-family: var(--mono); font-size: .85rem; color: var(--muted); }
h1 { margin: 0; font-size: clamp(2.5rem, 6vw, 4rem); font-weight: 800; letter-spacing: -.04em; line-height: 1; color: var(--ink); }
.lede { max-width: 42rem; margin: 1.25rem 0 0; font-family: "Source Serif 4", Georgia, serif; font-size: clamp(1.1rem, 1vw + .9rem, 1.3rem); line-height: 1.55; color: var(--text); }
table { width: 100%; min-width: 32rem; border-collapse: collapse; font-size: .97rem; border: 1px solid var(--line); border-radius: 14px; overflow: hidden; }
th { text-align: left; padding: .75rem 1rem; background: var(--surface); border-bottom: 1px solid var(--line); font-family: var(--mono); font-size: .75rem; font-weight: 500;
  letter-spacing: .04em; text-transform: uppercase; color: var(--soft); }
td { padding: .8rem 1rem; border-bottom: 1px solid var(--line); vertical-align: middle; overflow-wrap: anywhere; }
tbody tr:first-child td { background: color-mix(in srgb, var(--accent) 7%, transparent); }
tbody tr:first-child td:first-child { color: var(--accent); font-weight: 800; }
tbody tr:last-child td { border-bottom: 0; }
td:first-child { font-family: var(--mono); color: var(--muted); width: 3.5rem; }
td:nth-child(2) { font-weight: 700; color: var(--ink); }
td[colspan] { font-family: var(--sans); color: var(--muted); font-style: italic; font-weight: 500; }
th.num, td.num { text-align: right; font-variant-numeric: tabular-nums; font-family: var(--mono); }
.side { flex: 1 1 17rem; display: flex; flex-direction: column; gap: 1.5rem; background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 1.5rem; }
.block { display: flex; flex-direction: column; gap: .9rem; }
.label { margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--ink); }
.link { width: fit-content; font-weight: 700; color: var(--ink); text-decoration: none; padding-block: .4rem; }
.link:hover { text-decoration: underline; }
.note { margin: 0; padding-top: 1.25rem; border-top: 1px solid var(--line-strong); font-size: .9rem; line-height: 1.55; color: var(--muted); }
footer { background: var(--foot-bg); color: #c9d4df; font-size: .92rem; }
footer .wrap { padding-block: 3rem 1.75rem; display: grid; gap: 1.5rem; }
footer p { margin: 0; }
.foot-bio { display: flex; gap: 1rem; align-items: flex-start; max-width: 32rem; }
.foot-bio .mark { width: 2.75rem; height: 2.75rem; }
footer a { color: #fff; font-weight: 600; text-decoration: none; }
footer a:hover { color: #fff; text-decoration: underline; }
.foot-links { line-height: 2.2; }
.foot-copy { border-top: 1px solid #24476b; padding-top: 1.1rem; font-family: var(--mono); font-size: .75rem; color: #a9bbcd; }
@media (max-width: 40rem) { nav { width: 100%; gap: 0 1.1rem; } nav .btn { margin-left: auto; } }`;

/** A page in the icelander.net look: the site's header, the main column beside a side panel, and the site's footer. */
export function sitePage(title: string, main: string, side: string, status = 200, robots = "index, follow"): Response {
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#071726" media="(prefers-color-scheme: dark)">
<meta name="robots" content="${robots}">
<meta name="referrer" content="same-origin">
<title>${escapeHtml(title)} · David Brandt</title>
<link rel="icon" type="image/svg+xml" href="${ICON}">
<style>${CSS}</style>
</head>
<body>
<a class="skip" href="#main">Skip to the text</a>
<header class="site-head"><div class="wrap head-row">
<a class="brand" href="https://icelander.net/">${mark()}<span>David Brandt</span></a>
<nav aria-label="Site"><a href="https://icelander.net/trains">Writing</a><a href="/games/" aria-current="page">Games</a><a href="https://icelander.net/resume">Resume</a><a href="https://icelander.net/">About</a><a class="btn" href="https://icelander.net/#contact">Work with me</a></nav>
</div></header>
<main class="wrap page" id="main">
<div class="layout">
<section class="main">
${main}
</section>
<aside class="side">
${side}
</aside>
</div>
</main>
<footer><div class="wrap">
<div class="foot-bio">${mark("mark on-dark")}<p>David Brandt is a computer scientist, systems architect and independent scholar based in Reykjavík.</p></div>
<p class="foot-links"><a href="https://icelander.net/trains">Trains of thought</a> · <a href="/games/">Games</a> · <a href="https://icelander.net/resume">Resume</a> · <a href="https://icelander.net/">About and contact</a> · <a href="/privacy">Privacy</a> · <a href="/terms">Terms</a></p>
<p class="foot-copy">© David Brandt · icelander.net</p>
</div></footer>
</body>
</html>
`;
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Robots-Tag": robots === "index, follow" ? "all" : "noindex, nofollow",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "same-origin",
      "Content-Security-Policy": "default-src 'none'; script-src https://static.cloudflareinsights.com; connect-src 'self' https://cloudflareinsights.com; style-src 'unsafe-inline'; img-src data:; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    },
  });
}

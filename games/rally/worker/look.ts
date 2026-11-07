// The look of icelander.net (the same as the games page, in the recreations repository), for
// Rally's public high-score page: a deep-ocean background with a faint
// grid, the "icelander.net" mark, a light card with a serif heading, and a dark side panel.
// Only system fonts and inline CSS, so the strict CSP below holds.
export const escapeHtml = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

const ICON = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%2306213d'/%3E%3Cpath d='M17 18h14c11 0 17 5 17 14s-6 14-17 14H17V18Zm10 8v12h5c4 0 6-2 6-6s-2-6-6-6h-5Z' fill='%23f4fbff'/%3E%3C/svg%3E";

const CSS = `
:root { color-scheme: dark; --deep: #061a2f; --ocean: #0a3457; --ice: #edf8ff; --ink: #0b1d2b; --muted: #506675;
  --line: rgba(9, 47, 76, .14); --card: rgba(247, 252, 255, .97); --accent: #0d78af; }
* { box-sizing: border-box; }
html { min-height: 100%; }
body { min-height: 100vh; margin: 0; display: grid; place-items: center; padding: clamp(1rem, 5vw, 4rem); overflow-x: hidden;
  font-family: Inter, ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: var(--ice);
  background: radial-gradient(circle at 19% 20%, rgba(38, 155, 205, .28), transparent 31rem),
    radial-gradient(circle at 87% 78%, rgba(69, 193, 192, .13), transparent 28rem), linear-gradient(145deg, var(--deep), var(--ocean)); }
body::before { content: ""; position: fixed; inset: 0; pointer-events: none; opacity: .33;
  background-image: linear-gradient(rgba(255,255,255,.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.035) 1px, transparent 1px);
  background-size: 48px 48px; mask-image: linear-gradient(to bottom, black, transparent 86%); }
.page { width: min(100%, 69rem); position: relative; }
.site-mark { margin: 0 0 1.15rem; display: flex; align-items: center; gap: .75rem; font-size: .76rem; font-weight: 700; letter-spacing: .18em; text-transform: uppercase; }
.site-mark::before { content: ""; width: 1.8rem; height: 2px; background: #73c8e9; }
.site-mark a { color: rgba(237, 248, 255, .76); text-decoration: none; }
.site-mark a:hover { color: #9edffa; }
.card { display: grid; grid-template-columns: minmax(0, 1.6fr) minmax(17rem, .72fr); min-height: 30rem; overflow: hidden; color: var(--ink);
  background: var(--card); border: 1px solid rgba(255,255,255,.72); border-radius: 1.6rem; box-shadow: 0 2rem 6rem rgba(0, 10, 24, .35); }
.main { padding: clamp(2rem, 6vw, 5.25rem); display: flex; flex-direction: column; gap: 2.5rem; }
.eyebrow { margin: 0 0 1.25rem; color: var(--accent); font-size: .8rem; font-weight: 800; letter-spacing: .17em; text-transform: uppercase; }
h1 { margin: 0; font-family: Georgia, "Times New Roman", serif; font-size: clamp(3.1rem, 8vw, 6.2rem); font-weight: 500; line-height: .91; letter-spacing: -.055em; }
.lede { max-width: 40rem; margin: 1.5rem 0 0; color: #3b5262; font-size: clamp(1rem, 2vw, 1.17rem); line-height: 1.65; }
.games { list-style: none; margin: 0; padding: 0; display: grid; gap: 1rem; }
.game { display: block; padding: 1.25rem 1.4rem; border: 1px solid var(--line); border-radius: 1rem; color: var(--ink); text-decoration: none;
  background: #fff; transition: border-color .2s ease, box-shadow .2s ease, transform .2s ease; }
.game:hover { border-color: rgba(13, 120, 175, .45); box-shadow: 0 .8rem 2rem rgba(6, 33, 61, .12); transform: translateY(-1px); }
.game-title { font-family: Georgia, "Times New Roman", serif; font-size: 1.6rem; letter-spacing: -.03em; }
.tag { margin-left: .6rem; padding: .15rem .55rem; border-radius: 999px; font-size: .68rem; font-weight: 800; letter-spacing: .12em;
  text-transform: uppercase; vertical-align: middle; color: var(--accent); background: #e7f2f8; }
.tag.members { color: #fff; background: var(--ocean); }
.blurb { margin: .5rem 0 0; color: #3b5262; line-height: 1.55; }
.side { padding: clamp(2rem, 4vw, 3.25rem); display: flex; flex-direction: column; justify-content: space-between; gap: 2.5rem; color: var(--ice);
  background: linear-gradient(rgba(255,255,255,.045), rgba(255,255,255,0)), var(--deep); }
.monogram { width: 4.25rem; height: 4.25rem; display: grid; place-items: center; border: 1px solid rgba(255,255,255,.2); border-radius: 1.1rem;
  color: white; background: rgba(255,255,255,.07); font-family: Georgia, "Times New Roman", serif; font-size: 1.4rem; letter-spacing: -.05em; text-decoration: none; }
.block { display: grid; gap: 1rem; }
.label { margin: 0; color: #83b5cc; font-size: .72rem; font-weight: 800; letter-spacing: .17em; text-transform: uppercase; }
.who { margin: 0; overflow-wrap: anywhere; line-height: 1.5; }
.side a.link { width: fit-content; color: white; text-decoration: none; border-bottom: 1px solid rgba(255,255,255,.3); }
.side a.link:hover { color: #9edffa; border-color: #9edffa; }
.button { width: fit-content; padding: .68rem .9rem; border: 1px solid rgba(255,255,255,.18); border-radius: .65rem; color: #cfe8f4;
  background: rgba(255,255,255,.07); font: inherit; font-size: .82rem; font-weight: 750; cursor: pointer; text-decoration: none; }
.button:hover { background: rgba(255,255,255,.13); border-color: rgba(255,255,255,.3); }
.note { margin: 0; padding-top: 1.5rem; border-top: 1px solid rgba(255,255,255,.14); color: #91afbe; font-size: .78rem; line-height: 1.55; }
.side ul { margin: 0; padding-left: 1.1rem; color: #cfe8f4; font-size: .85rem; line-height: 1.7; overflow-wrap: anywhere; }
.back { margin: 1.15rem 0 0; color: rgba(237, 248, 255, .55); font-size: .82rem; font-weight: 600; line-height: 1.8; }
.back a { color: rgba(237, 248, 255, .82); text-decoration: none; border-bottom: 1px solid rgba(237, 248, 255, .3); }
.back a:hover { color: #9edffa; border-color: #9edffa; }
a:focus-visible, button:focus-visible, input:focus-visible { outline: 3px solid #56b9e5; outline-offset: 3px; }
form.add { display: flex; gap: .6rem; flex-wrap: wrap; align-items: end; }
form.add label { width: 100%; color: var(--muted); font-size: .9rem; }
input[type=text] { flex: 1 1 16rem; min-height: 2.75rem; padding: .6rem .8rem; font: inherit; color: var(--ink); background: #fff; border: 1px solid var(--line); border-radius: .65rem; }
.primary { min-height: 2.75rem; padding: .6rem 1.1rem; border: 0; border-radius: .65rem; color: #fff; background: var(--ocean); font: inherit; font-weight: 750; cursor: pointer; }
.primary:hover { background: var(--accent); }
.message { margin: 0; padding: .8rem 1rem; border-radius: .65rem; color: #7a1c1c; background: #fdecec; }
table { width: 100%; border-collapse: collapse; font-size: .95rem; }
th { text-align: left; color: var(--muted); font-size: .72rem; font-weight: 800; letter-spacing: .14em; text-transform: uppercase; padding: 0 .4rem .6rem; }
td { padding: .55rem .4rem; border-top: 1px solid var(--line); vertical-align: middle; overflow-wrap: anywhere; }
td.by { color: var(--muted); font-size: .82rem; }
th.num, td.num { text-align: right; font-variant-numeric: tabular-nums; }
td form { margin: 0; text-align: right; }
.remove { padding: .35rem .7rem; border: 1px solid var(--line); border-radius: .5rem; color: #7a1c1c; background: #fff; font: inherit; font-size: .8rem; cursor: pointer; }
.remove:hover { background: #fdecec; }
form.inline { margin: 0; }
@media (max-width: 760px) {
  body { align-items: start; padding: 1.1rem; }
  .page { margin-block: 1.5rem; }
  .card { grid-template-columns: 1fr; }
  .main { padding: 2rem; }
  .side { padding: 2rem; }
  h1 { font-size: clamp(3.2rem, 16vw, 4.8rem); }
}
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { transition-duration: .01ms !important; } }`;

/** A page in the icelander.net look: the main column, the dark side panel, and the links back to the site. */
export function sitePage(title: string, main: string, side: string, status = 200, robots = "index, follow"): Response {
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#06213d">
<meta name="robots" content="${robots}">
<meta name="referrer" content="same-origin">
<title>${escapeHtml(title)} · David Brandt</title>
<link rel="icon" type="image/svg+xml" href="${ICON}">
<style>${CSS}</style>
</head>
<body>
<main class="page">
<p class="site-mark"><a href="https://icelander.net/">icelander.net</a></p>
<article class="card">
<section class="main">
${main}
</section>
<aside class="side">
<a class="monogram" href="https://icelander.net/" aria-label="icelander.net">DB</a>
${side}
</aside>
</article>
<p class="back"><a href="https://icelander.net/trains">Trains of thought</a> · <a href="/">Games</a> · <a href="https://icelander.net/">About and contact</a> · <a href="https://icelander.net/feed.xml">Feed of everything</a></p>
</main>
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
      "Content-Security-Policy": "default-src 'none'; script-src https://static.cloudflareinsights.com; connect-src 'self' https://cloudflareinsights.com; style-src 'unsafe-inline'; img-src data:; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    },
  });
}

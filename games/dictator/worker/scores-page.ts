// The public high-score page, /games/retro/samosa/scores/: the same table the game shows on its
// title screen (S), as a web page in icelander.net's look.
import { escapeHtml, sitePage } from "./look";

export interface Row { name: string; score: number; months: number; alive: boolean }

export function scoresPage(rows: Row[]): Response {
  const body = rows.length
    ? rows.map((r, i) => `<tr><td>${i + 1}</td><td>${escapeHtml(r.name)}</td><td class="num">${r.score}</td><td class="num">${r.months}</td><td>${r.alive ? "Fled" : "Died"}</td></tr>`).join("\n")
    : `<tr><td colspan="5">No reign recorded yet. Be the first.</td></tr>`;
  const main = `<div>
<p class="eyebrow">Games · Samosa</p>
<h1>High scores</h1>
<p class="lede">The most glorious reigns of President Ortiga. Every score is checked: the server replays the whole reign from its key presses before it is listed.</p>
</div>
<table>
<thead><tr><th>No</th><th>Name</th><th class="num">Score</th><th class="num">Months</th><th>Fate</th></tr></thead>
<tbody>
${body}
</tbody>
</table>`;
  const side = `<div class="block">
<p class="label">Samosa</p>
<a class="button" href="/games/retro/samosa/">Play Samosa</a>
<a class="link" href="/games/">← All the games</a>
</div>
<p class="note">Only the part of a player's email before the @ is shown. Enter the table at the end of a reign.</p>`;
  return sitePage("Samosa high scores", main, side);
}

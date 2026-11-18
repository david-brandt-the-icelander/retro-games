// The public high-score page, /games/retro/meg/scores/: the table the game shows, as a web page in icelander.net's look.
import { escapeHtml, sitePage } from "./look";
import type { Row } from "./scores";

export function scoresPage(rows: Row[]): Response {
  const body = rows.length
    ? rows.map((r, i) => `<tr><td>${i + 1}</td><td>${escapeHtml(r.name)}</td><td class="num">${r.score.toLocaleString("en-US")}</td><td class="num">${r.file}</td></tr>`).join("\n")
    : `<tr><td colspan="4">No score recorded yet. Be the first.</td></tr>`;
  const main = `<div>
<p class="eyebrow">Games · MEG</p>
<h1>High scores</h1>
<p class="lede">The hungriest megalodons, and the furthest each got through the Directorate's incident files. Scores are sent by the game at the end of a run and checked against how long the run lasted.</p>
</div>
<table>
<thead><tr><th>No</th><th>Name</th><th class="num">Score</th><th class="num">File</th></tr></thead>
<tbody>
${body}
</tbody>
</table>`;
  const side = `<div class="block">
<p class="label">MEG</p>
<a class="button" href="${"/games/retro/meg/"}">Play MEG</a>
<a class="link" href="/games/">← All the games</a>
</div>
<p class="note">Players enter the table with a name of their choosing when their run ends.</p>`;
  return sitePage("MEG high scores", main, side);
}

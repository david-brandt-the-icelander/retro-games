// The public high-score page, /retro/rally/scores/: the same table the game shows, as a
// web page in icelander.net's look.
import { escapeHtml, sitePage } from "./look";
import type { Row } from "./scores";

const LEVEL = { easy: "Easy", normal: "Normal", hard: "Hard" } as const;

export function scoresPage(rows: Row[]): Response {
  const body = rows.length
    ? rows.map((r, i) => `<tr><td>${i + 1}</td><td>${escapeHtml(r.name)}</td><td class="num">${r.score}</td><td>${LEVEL[r.level] ?? ""}</td><td>${r.won ? "Won" : "Lost"} ${r.mine}–${r.theirs}</td></tr>`).join("\n")
    : `<tr><td colspan="5">No match recorded yet. Be the first.</td></tr>`;
  const main = `<div>
<p class="eyebrow">Games · Rally</p>
<h1>High scores</h1>
<p class="lede">The best one-player matches against the computer. Each point won scores 100 on easy, 200 on normal and 300 on hard; winning the match adds ten points' worth. Every score is checked: the server replays the whole match from the player's paddle moves before it is listed.</p>
</div>
<table>
<thead><tr><th>No</th><th>Name</th><th class="num">Score</th><th>Computer</th><th>Match</th></tr></thead>
<tbody>
${body}
</tbody>
</table>`;
  const side = `<div class="block">
<p class="label">Rally</p>
<a class="button" href="/retro/rally/">Play Rally</a>
<a class="link" href="/">← All the games</a>
</div>
<p class="note">Enter the table at the end of a one-player match, under a name of up to 12 characters.</p>`;
  return sitePage("Rally high scores", main, side);
}

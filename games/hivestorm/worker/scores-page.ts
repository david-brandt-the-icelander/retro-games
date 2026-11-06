// The public high-score page, /games/retro/hivestorm/scores/: the table the game shows between
// title screens, as a web page in icelander.net's look.
import { escapeHtml, sitePage } from "./look";

export interface Row { name: string; score: number; wave: number; players: number }

export function scoresPage(rows: Row[]): Response {
  const body = rows.length
    ? rows.map((r, i) => `<tr><td>${i + 1}</td><td>${escapeHtml(r.name)}</td><td class="num">${r.score}</td><td class="num">${r.wave}</td><td>${r.players === 2 ? "2 players" : "1 player"}</td></tr>`).join("\n")
    : `<tr><td colspan="5">No score recorded yet. Be the first.</td></tr>`;
  const main = `<div>
<p class="eyebrow">Games · Hivestorm</p>
<h1>High scores</h1>
<p class="lede">The best pilots against the hive. Every score is checked: the server plays the whole game again from its recorded controls before it is listed.</p>
</div>
<table>
<thead><tr><th>No</th><th>Name</th><th class="num">Score</th><th class="num">Wave</th><th>Game</th></tr></thead>
<tbody>
${body}
</tbody>
</table>`;
  const side = `<div class="block">
<p class="label">Hivestorm</p>
<a class="button" href="/games/retro/hivestorm/">Play Hivestorm</a>
<a class="link" href="/games/">← All the games</a>
</div>
<p class="note">Players enter the table with a name of their choosing when their game ends. In a two-player game, each player can enter their own score.</p>`;
  return sitePage("Hivestorm high scores", main, side);
}

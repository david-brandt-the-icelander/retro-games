// The public high-score page, /retro/shatterbelt/scores/: the same table the game shows on its
// title screen, as a web page in icelander.net's look.
import { escapeHtml, sitePage } from "./look";

export interface Row { name: string; score: number; wave: number; mode: string; players: number }

export const modeLabel = (r: Pick<Row, "mode" | "players">): string =>
  r.mode === "versus" ? `Versus, ${r.players} players` : r.players === 1 ? "Solo" : `Co-op, ${r.players} players`;

export function scoresPage(rows: Row[]): Response {
  const body = rows.length
    ? rows.map((r, i) => `<tr><td>${i + 1}</td><td>${escapeHtml(r.name)}</td><td class="num">${r.score.toLocaleString("en-US")}</td><td class="num">${r.wave}</td><td>${escapeHtml(modeLabel(r))}</td></tr>`).join("\n")
    : `<tr><td colspan="5">No pilot on the board yet. Be the first.</td></tr>`;
  const main = `<div>
<p class="eyebrow">Games · Shatterbelt</p>
<h1>High scores</h1>
<p class="lede">The best pilots of the belt. Every score is checked: the server replays the whole game, from every press of every player's controls, before it is listed.</p>
</div>
<table>
<thead><tr><th>No</th><th>Pilot</th><th class="num">Score</th><th class="num">Wave</th><th>Game</th></tr></thead>
<tbody>
${body}
</tbody>
</table>`;
  const side = `<div class="block">
<p class="label">Shatterbelt</p>
<a class="button" href="/retro/shatterbelt/">Play Shatterbelt</a>
<a class="link" href="/">← All the games</a>
</div>
<p class="note">Pilots enter their names at the end of a game; only the name is kept. Each player's own score counts, in co-op as in versus.</p>`;
  return sitePage("Shatterbelt high scores", main, side);
}

// The walkthrough on the start and join pages: five illustrated steps built from the game's own
// cards, so a first-time player sees what the board, the key and a guess look like before they
// are in a room. It holds its own state (the step) and is redrawn in place, so the room's updates
// to the join page never reset it. Every word is in text.ts.
import { TOUR } from "./text";

type Kind = "hraun" | "jokull" | "neutral" | "ghost";

const ICON: Record<Kind, string> = {
  hraun: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M1.5 22 8.5 10h7l7 12z" fill="currentColor"/><path d="M12 8V5M8.5 6.5 7 4.5M15.5 6.5 17 4.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/></svg>`,
  jokull: `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 2v20M3.3 7l17.4 10M3.3 17 20.7 7M9 3.5l3 2 3-2M9 20.5l3-2 3 2"/></svg>`,
  neutral: `<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="5" fill="none" stroke="currentColor" stroke-width="2.4"/></svg>`,
  ghost: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4.5 22V10.5a7.5 7.5 0 0 1 15 0V22l-2.6-2-2.4 2-2.5-2-2.5 2-2.4-2z" fill="currentColor"/><circle cx="9.3" cy="10.8" r="1.6" fill="#1b1325"/><circle cx="14.7" cy="10.8" r="1.6" fill="#1b1325"/></svg>`,
};

/** A card of the mock board: plain, as the guessers see it; key, as a clue-giver sees it; or revealed. */
type Mode = "plain" | "key" | "revealed";
interface Cell { w: string; k: Kind; mode?: Mode; pick?: boolean }

const WORDS: readonly [string, Kind][] = [
  ["Sjór", "hraun"], ["Fjall", "jokull"], ["Hestur", "neutral"], ["Kaffi", "jokull"], ["Vindur", "hraun"],
  ["Hraun", "neutral"], ["Skip", "hraun"], ["Ís", "jokull"], ["Bók", "neutral"], ["Lamb", "neutral"],
  ["Foss", "jokull"], ["Hver", "hraun"], ["Draugur", "ghost"], ["Snjór", "jokull"], ["Gítar", "neutral"],
];

const cell = (c: Cell): string => {
  const mode = c.mode ?? "plain";
  const cls = mode === "plain" ? "card" : mode === "key" ? `card key k-${c.k}` : `card revealed k-${c.k}`;
  const icon = mode === "plain" ? "" : `<span class="cicon">${ICON[c.k]}</span>`;
  return `<span class="${cls}${c.pick ? " picked" : ""}">${icon}<span class="w">${c.w}</span></span>`;
};

/** A 5×3 mock of the board: enough to show the idea without crowding a phone. */
function board(mode: Mode, tweak: (i: number, c: Cell) => Cell = (_, c) => c): string {
  const cells = WORDS.map(([w, k], i) => tweak(i, { w, k, mode }));
  return `<div class="tboard" aria-hidden="true">${cells.map(cell).join("")}</div>`;
}

const ART: readonly (() => string)[] = [
  // 1. Two teams
  () => `<div class="tteams" aria-hidden="true">
    <div class="tteam t-hraun"><span class="ticon">${ICON.hraun}</span><b>Hraun</b><small>${TOUR.giver} · ${TOUR.guessers}</small></div>
    <span class="tvs">${TOUR.versus}</span>
    <div class="tteam t-jokull"><span class="ticon">${ICON.jokull}</span><b>Jökull</b><small>${TOUR.giver} · ${TOUR.guessers}</small></div>
  </div>`,
  // 2. The board, with every word the same
  () => board("plain"),
  // 3. The clue-giver's key and a clue
  () => `<div class="tclue t-hraun" aria-hidden="true"><span>${TOUR.clueLabel}</span><b>Sjór · 2</b></div>${board("key")}`,
  // 4. Guessing: a right word, then a wrong one
  () => board("revealed", (i, c) => {
    if (i === 0) return { ...c, mode: "revealed" };
    if (i === 6) return { ...c, mode: "revealed" };
    if (i === 5) return { ...c, mode: "revealed", k: "neutral" };
    if (i === 11) return { ...c, mode: "plain", pick: true };
    return { ...c, mode: "plain" };
  }),
  // 5. The ghost
  () => board("plain", (i, c) => (i === 12 ? { ...c, mode: "revealed", k: "ghost" } : c)),
];

let step = 0;

const dots = (): string => `<div class="tdots" role="tablist" aria-label="${TOUR.title}">${TOUR.steps.map((_, i) =>
  `<button type="button" role="tab" class="tdot${i === step ? " on" : ""}" aria-selected="${i === step}" aria-label="${TOUR.stepLabel(i + 1, TOUR.steps.length)}" data-tour="go" data-i="${i}"></button>`).join("")}</div>`;

function inner(): string {
  const s = TOUR.steps[step]!;
  const last = step === TOUR.steps.length - 1;
  return `<div class="tstage">${ART[step]!()}</div>
    <div class="tcopy" aria-live="polite"><p class="tkick">${TOUR.stepLabel(step + 1, TOUR.steps.length)}</p><h3>${s.title}</h3><p>${s.body}</p></div>
    ${dots()}
    <div class="tnav">
      <button type="button" class="btn small ghostbtn" data-tour="back" ${step === 0 ? "disabled" : ""}>${TOUR.back}</button>
      <button type="button" class="btn small ${last ? "" : "primary"}" data-tour="${last ? "restart" : "next"}">${last ? TOUR.again : TOUR.next}</button>
    </div>`;
}

/** The walkthrough's frame, for a page to drop in. */
export function tourHtml(): string {
  return `<section class="panel tour" id="tour" aria-label="${TOUR.title}"><h2>${TOUR.title}</h2><div id="tour-body">${inner()}</div></section>`;
}

/** Clicks and arrow keys, once for the page. */
export function bindTour(): void {
  const redraw = (): void => { const el = document.getElementById("tour-body"); if (el) el.innerHTML = inner(); };
  const go = (n: number): void => { step = Math.max(0, Math.min(TOUR.steps.length - 1, n)); redraw(); };
  document.addEventListener("click", (e) => {
    const el = (e.target as HTMLElement).closest<HTMLElement>("[data-tour]");
    if (!el || (el as HTMLButtonElement).disabled) return;
    switch (el.dataset.tour) {
      case "next": go(step + 1); break;
      case "back": go(step - 1); break;
      case "restart": go(0); break;
      case "go": go(Number(el.dataset.i)); break;
    }
    const again = el.dataset.tour === "go" ? `[data-tour="go"][data-i="${el.dataset.i}"]` : `[data-tour="${el.dataset.tour === "restart" ? "next" : el.dataset.tour}"]`;
    document.querySelector<HTMLElement>(`#tour ${again}`)?.focus();
  });
  document.addEventListener("keydown", (e) => {
    if (!(e.target as HTMLElement | null)?.closest?.("#tour")) return;
    if (e.key === "ArrowRight") go(step + 1);
    else if (e.key === "ArrowLeft") go(step - 1);
  });
}

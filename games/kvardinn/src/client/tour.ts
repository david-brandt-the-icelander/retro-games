// The walkthrough on the front page and the join page: six illustrated steps drawn with the
// game's own scale, pointer and scoring bands, so a first-time player sees what a round looks
// like before they are in one. The step lives here; render() redraws the page from scratch, so
// each click only changes the step and asks for a redraw.
import { BANDS } from "../engine/game";

interface Step { title: string; body: string }

const STEPS: readonly Step[] = [
  { title: "Tvö lið, hvert á sínum síma", body: "Aldan og Sólin keppast um stigin. Hópurinn getur setið í sama herbergi eða verið langt hvert frá öðru." },
  { title: "Spjald með tveimur andstæðum", body: "Spjaldið sýnir kvarða, til dæmis Kalt og Heitt. Appið felur leynimark einhvers staðar á honum." },
  { title: "Sá sem gefur vísbendingu sér markið", body: "Aðeins hann eða hún sér hvar markið er, og segir stutta vísbendingu sem á heima einmitt þar. Hér er það nokkuð heitt: „kakó“." },
  { title: "Liðið dregur vísinn", body: "Liðið ræðir saman og dregur sameiginlegan vísi þangað sem það heldur að markið sé. Hann hreyfist í beinni á öllum símum." },
  { title: "Hitt liðið veðjar", body: "Hitt liðið má giska á hvort markið sé vinstra eða hægra megin við vísinn. Rétt ágiskun gefur 1 stig." },
  { title: "Afhjúpunin", body: "Nálægt miðju marksins gefur 4 stig, svo 3 og 2. Fyrsta liðið sem nær markinu vinnur." },
];
const LABELS = { step: (n: number, of: number) => `Skref ${n} af ${of}`, next: "Næsta", back: "Til baka", again: "Sjá aftur", title: "Svona fer umferð fram" };

const TARGET = 72;
const BAND_W = [BANDS[2] - BANDS[1], BANDS[1] - BANDS[0], BANDS[0] * 2, BANDS[1] - BANDS[0], BANDS[2] - BANDS[1]];

/** The scale mock: a bar with optional bands around the target, a pointer, and an optional hidden-target marker. */
function track(o: { bands?: boolean; target?: boolean; pointer?: number; hint?: "?" }): string {
  const left = TARGET - BANDS[2];
  const bands = o.bands
    ? `<div class="mbands" style="left:${left}%;width:${BANDS[2] * 2}%">${["b2", "b3", "b4", "b3", "b2"].map((c, i) => `<i class="${c}" style="width:${(BAND_W[i]! / (BANDS[2] * 2)) * 100}%">${c.slice(1)}</i>`).join("")}</div>`
    : "";
  const target = o.target ? `<div class="mtarget" style="left:${TARGET}%"></div>` : "";
  const hidden = o.hint ? `<div class="mhidden" style="left:${TARGET}%">?</div>` : "";
  const needle = o.pointer !== undefined ? `<div class="mneedle" style="left:${o.pointer}%"><i></i></div>` : "";
  return `<div class="mscale"><div class="mends"><b class="l">Kalt</b><span>↔</span><b class="r">Heitt</b></div><div class="mtrack">${bands}${target}${hidden}${needle}</div></div>`;
}

const ART: readonly (() => string)[] = [
  () => `<div class="mteams"><div class="mteam t0"><b>Aldan</b><span>🔵 🔵</span></div><span class="mvs">á móti</span><div class="mteam t1"><b>Sólin</b><span>🟠 🟠</span></div></div>`,
  () => track({ hint: "?" }),
  () => `${track({ bands: true, target: true })}<div class="mclue">Sá sem gefur vísbendingu: <b>„Kakó“</b></div>`,
  () => `${track({ pointer: 66 })}<div class="mhandrow"><span>◀</span><b>dragðu</b><span>▶</span></div>`,
  () => `${track({ pointer: 58 })}<div class="mbet"><span class="btn small">◀ Vinstra megin</span><span class="btn small pick">Hægra megin ▶</span></div>`,
  () => `${track({ bands: true, target: true, pointer: 66 })}<div class="mscore">4 · 3 · 2 stig</div>`,
];

let step = 0;

/** The walkthrough's panel. */
export function tourHtml(): string {
  const s = STEPS[step]!;
  const last = step === STEPS.length - 1;
  const dots = STEPS.map((_, i) => `<button type="button" role="tab" class="tdot${i === step ? " on" : ""}" aria-selected="${i === step}" aria-label="${LABELS.step(i + 1, STEPS.length)}" data-tour="go" data-i="${i}"></button>`).join("");
  return `<section class="panel tour" id="tour" aria-label="${LABELS.title}">
    <h2>${LABELS.title}</h2>
    <div class="tstage" aria-hidden="true">${ART[step]!()}</div>
    <div class="tcopy" aria-live="polite"><p class="tkick">${LABELS.step(step + 1, STEPS.length)}</p><h3>${s.title}</h3><p>${s.body}</p></div>
    <div class="tdots" role="tablist" aria-label="${LABELS.title}">${dots}</div>
    <div class="tnav">
      <button type="button" class="btn small ghost" data-tour="back" ${step === 0 ? "disabled" : ""}>${LABELS.back}</button>
      <button type="button" class="btn small${last ? "" : " primary"}" data-tour="${last ? "restart" : "next"}">${last ? LABELS.again : LABELS.next}</button>
    </div>
  </section>`;
}

/** Clicks and arrow keys, once for the page; `redraw` is the page's render. */
export function bindTour(redraw: () => void): void {
  const go = (n: number): void => { step = Math.max(0, Math.min(STEPS.length - 1, n)); redraw(); };
  const refocus = (sel: string): void => document.querySelector<HTMLElement>(`#tour ${sel}`)?.focus();
  document.addEventListener("click", (e) => {
    const el = (e.target as HTMLElement).closest<HTMLElement>("[data-tour]");
    if (!el || (el as HTMLButtonElement).disabled) return;
    const what = el.dataset.tour;
    if (what === "next") { go(step + 1); refocus(`[data-tour="${step === STEPS.length - 1 ? "restart" : "next"}"]`); }
    else if (what === "back") { go(step - 1); refocus(`[data-tour="${step === 0 ? "next" : "back"}"]`); }
    else if (what === "restart") { go(0); refocus('[data-tour="next"]'); }
    else if (what === "go") { go(Number(el.dataset.i)); refocus(`[data-tour="go"][data-i="${el.dataset.i}"]`); }
  });
  document.addEventListener("keydown", (e) => {
    if (!(e.target as HTMLElement | null)?.closest?.("#tour")) return;
    if (e.key === "ArrowRight") go(step + 1);
    else if (e.key === "ArrowLeft") go(step - 1);
  });
}

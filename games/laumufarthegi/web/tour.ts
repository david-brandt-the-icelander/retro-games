// The walkthrough on the start and join pages: five illustrated steps that show what a round of
// Laumufarþegi looks like (the topic and its 16 words, who sees the secret word, the clues, the
// vote and the stowaway's guess) before the player is in a room. The step is kept here; the
// page redraws itself from scratch on every update, so each tap changes the step and asks for a
// redraw. Everything is static text written here, and the page's policy allows no inline style,
// so the pictures are made of classes only.

interface Step { title: string; body: string }

const STEPS: readonly Step[] = [
  { title: "Efni og 16 orð", body: "Allir sjá sama efnið og sömu 16 orðin. Eitt þeirra er leyniorðið." },
  { title: "Allir nema einn vita leyniorðið", body: "Laumufarþeginn sér bara efnið og orðin. Hann þarf að þykjast vita hvað er leyniorðið." },
  { title: "Vísbendingar á víxl", body: "Hver gefur stutta vísbendingu um leyniorðið. Of augljós vísbending hjálpar laumufarþeganum, of óljós vekur grun." },
  { title: "Kosið um laumufarþegann", body: "Þegar allir hafa talað kjósa allir þann sem þeir halda að sé laumufarþeginn. Rétt atkvæði gefur 1 stig." },
  { title: "Síðasta tækifærið", body: "Náist laumufarþeginn má hann giska á leyniorðið. Sleppi hann fær hann 3 stig. Flest stig í lokin vinna!" },
];
const L = { title: "Svona gengur leikurinn fyrir sig", step: (n: number, of: number) => `Skref ${n} af ${of}`, next: "Næsta", back: "Til baka", again: "Sjá aftur" };

const WORDS = ["Skel", "Þang", "Krabbi", "Máfur", "Bátur", "Net", "Sandur", "Alda", "Viti", "Fiskur", "Kría", "Selur", "Steinn", "Bryggja", "Sjór", "Vindur"];
const SECRET = 2;

type Mark = "secret" | "pick" | "";
function grid(mark: (i: number) => Mark, small = false, count = WORDS.length): string {
  return `<div class="tgrid${small ? " tsmall" : ""}${count < WORDS.length ? " thalf" : ""}">${WORDS.slice(0, count).map((w, i) => `<span class="tw ${mark(i)}">${w}</span>`).join("")}</div>`;
}
const topic = (t = "Í fjörunni") => `<p class="ttopic"><small>Efni</small><b>${t}</b></p>`;

const ART: readonly (() => string)[] = [
  () => `${topic()}${grid(() => "")}`,
  () => `<div class="tphones">
      <div class="tphone"><p class="trole crew">Áhöfn</p>${grid((i) => (i === SECRET ? "secret" : ""), true, 8)}<p class="tnote">Leyniorðið: <b>Krabbi</b></p></div>
      <div class="tphone"><p class="trole stow">Laumufarþegi</p>${grid(() => "", true, 8)}<p class="tnote">Leyniorðið: <b>?</b></p></div>
    </div>`,
  () => `<ol class="tclues"><li><span class="who">Sigga</span><span class="what">Klær</span></li><li><span class="who">Jón</span><span class="what">Strönd</span></li><li class="now"><span class="who">Anna</span><span class="what">skrifar…</span></li></ol>`,
  () => `<div class="tvote"><span class="vbtn">Sigga</span><span class="vbtn on">Jón <i>● ● ●</i></span><span class="vbtn">Anna <i>●</i></span></div><p class="tnote">Flest atkvæði: <b>Jón</b> – hann var laumufarþeginn!</p>`,
  () => `<p class="tnote">Jón fékk að giska:</p>${grid((i) => (i === SECRET ? "pick" : ""), true)}<p class="tscore"><span>Rétt gisk: <b>1 stig</b></span><span>Slapp: <b>3 stig</b></span></p>`,
];

let step = 0;

/** The walkthrough's card; `redraw` is the page's render. */
export function tour(redraw: () => void): HTMLElement {
  const last = step === STEPS.length - 1;
  const s = STEPS[step]!;
  const go = (n: number, focus: string): void => { step = Math.max(0, Math.min(STEPS.length - 1, n)); redraw(); document.querySelector<HTMLElement>(`#tour ${focus}`)?.focus(); };
  const sec = document.createElement("section");
  sec.className = "card tour";
  sec.id = "tour";
  sec.setAttribute("aria-label", L.title);
  const dots = STEPS.map((_, i) => `<button type="button" role="tab" class="tdot${i === step ? " on" : ""}" aria-selected="${i === step}" aria-label="${L.step(i + 1, STEPS.length)}" data-i="${i}"></button>`).join("");
  sec.innerHTML = `<h2>${L.title}</h2>
    <div class="tstage" aria-hidden="true">${ART[step]!()}</div>
    <div class="tcopy" aria-live="polite"><p class="tkick">${L.step(step + 1, STEPS.length)}</p><h3>${s.title}</h3><p>${s.body}</p></div>
    <div class="tdots" role="tablist" aria-label="${L.title}">${dots}</div>
    <div class="tnav"><button type="button" class="btn ghost" data-nav="back"${step === 0 ? " disabled" : ""}>${L.back}</button>
    <button type="button" class="btn${last ? "" : " primary"}" data-nav="${last ? "again" : "next"}">${last ? L.again : L.next}</button></div>`;
  sec.addEventListener("click", (e) => {
    const el = (e.target as HTMLElement).closest<HTMLElement>("[data-nav], [data-i]");
    if (!el || (el as HTMLButtonElement).disabled) return;
    if (el.dataset.i !== undefined) return go(Number(el.dataset.i), `[data-i="${el.dataset.i}"]`);
    if (el.dataset.nav === "next") go(step + 1, last || step + 1 === STEPS.length - 1 ? '[data-nav="again"]' : '[data-nav="next"]');
    else if (el.dataset.nav === "back") go(step - 1, step - 1 === 0 ? '[data-nav="next"]' : '[data-nav="back"]');
    else go(0, '[data-nav="next"]');
  });
  sec.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight") go(step + 1, '[role="tab"].on');
    else if (e.key === "ArrowLeft") go(step - 1, '[role="tab"].on');
  });
  return sec;
}

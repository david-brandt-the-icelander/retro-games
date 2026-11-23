// The scale: a long basalt bar between the card's two ends, the shared pointer ("vísirinn") and,
// for the clue-giver and after the reveal, the scoring bands around the target. One element that
// lives across re-renders, so a drag in progress is never interrupted.
import { BANDS } from "../engine/game";
import { playSweep } from "./sound";

export interface ScaleState {
  left: string;
  right: string;
  pointer: number;
  target: number | null;
  /** Can this device move the pointer? */
  movable: boolean;
  /** Team colour of the guessing team: "t0", "t1" or "coop". */
  tone: string;
  /** Play the reveal animation (once per round). */
  reveal: boolean;
  points: number | null;
}

export class Scale {
  readonly el: HTMLElement;
  private readonly track: HTMLElement;
  private readonly needle: HTMLElement;
  private readonly bands: HTMLElement;
  private readonly pop: HTMLElement;
  private readonly endL: HTMLElement;
  private readonly endR: HTMLElement;
  private readonly nudge: HTMLElement;
  private readonly hint: HTMLElement;
  private state: ScaleState | null = null;
  private value = 50;
  dragging = false;
  private lastSent = 0;
  private sendTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(private readonly onMove: (v: number, final: boolean) => void, private readonly onDragEnd: () => void) {
    const el = document.createElement("section");
    el.className = "scale";
    el.innerHTML = `
      <div class="ends"><div class="end end-l"></div><div class="end-arrow" aria-hidden="true">↔</div><div class="end end-r"></div></div>
      <div class="track" tabindex="0" role="slider" aria-valuemin="0" aria-valuemax="100" aria-label="Vísirinn">
        <div class="track-bg"></div>
        <div class="ticks" aria-hidden="true">${Array.from({ length: 11 }, (_, i) => `<i style="left:${i * 10}%"></i>`).join("")}</div>
        <div class="bands" aria-hidden="true"><i class="b2">2</i><i class="b3">3</i><i class="b4">4</i><i class="b3">3</i><i class="b2">2</i></div>
        <div class="needle"><div class="knob"></div></div>
        <div class="pop" aria-hidden="true"></div>
      </div>
      <div class="nudge">
        <button type="button" class="btn small" data-d="-5" aria-label="Færa vísinn mikið til vinstri">◀◀</button>
        <button type="button" class="btn small" data-d="-1" aria-label="Færa vísinn aðeins til vinstri">◀</button>
        <button type="button" class="btn small" data-d="1" aria-label="Færa vísinn aðeins til hægri">▶</button>
        <button type="button" class="btn small" data-d="5" aria-label="Færa vísinn mikið til hægri">▶▶</button>
      </div>
      <p class="hint">Dragðu vísinn eða notaðu örvatakkana.</p>`;
    this.el = el;
    const q = (s: string) => el.querySelector(s) as HTMLElement;
    this.track = q(".track");
    this.needle = q(".needle");
    this.bands = q(".bands");
    this.pop = q(".pop");
    this.endL = q(".end-l");
    this.endR = q(".end-r");
    this.nudge = q(".nudge");
    this.hint = q(".hint");

    this.track.addEventListener("pointerdown", (e) => {
      if (!this.state?.movable) return;
      e.preventDefault();
      this.track.setPointerCapture(e.pointerId);
      this.dragging = true;
      this.el.classList.add("dragging");
      this.setFromX(e.clientX);
    });
    this.track.addEventListener("pointermove", (e) => {
      if (this.dragging) this.setFromX(e.clientX);
    });
    const end = (e: PointerEvent) => {
      if (!this.dragging) return;
      this.dragging = false;
      this.el.classList.remove("dragging");
      try {
        this.track.releasePointerCapture(e.pointerId);
      } catch {
        /* already released */
      }
      this.flush(true);
      this.onDragEnd();
    };
    this.track.addEventListener("pointerup", end);
    this.track.addEventListener("pointercancel", end);
    this.track.addEventListener("keydown", (e) => {
      if (!this.state?.movable) return;
      const step = e.shiftKey ? 5 : 1;
      if (e.key === "ArrowLeft" || e.key === "ArrowDown") this.nudgeBy(-step);
      else if (e.key === "ArrowRight" || e.key === "ArrowUp") this.nudgeBy(step);
      else return;
      e.preventDefault();
    });
    this.nudge.addEventListener("click", (e) => {
      const b = (e.target as HTMLElement).closest("button[data-d]") as HTMLElement | null;
      if (b) this.nudgeBy(Number(b.dataset.d));
    });
  }

  private nudgeBy(d: number): void {
    this.setValue(this.value + d);
    this.flush(true);
  }

  private setFromX(x: number): void {
    const r = this.track.getBoundingClientRect();
    this.setValue(((x - r.left) / r.width) * 100);
    this.flush(false);
  }

  private setValue(v: number): void {
    this.value = Math.round(Math.min(100, Math.max(0, v)) * 10) / 10;
    this.placeNeedle(false);
  }

  /** Sends the pointer at most ~16 times a second while dragging, and always the final value. */
  private flush(final: boolean): void {
    const now = performance.now();
    if (this.sendTimer) clearTimeout(this.sendTimer);
    this.sendTimer = null;
    if (final || now - this.lastSent > 60) {
      this.lastSent = now;
      this.onMove(this.value, final);
    } else {
      this.sendTimer = setTimeout(() => this.flush(false), 60);
    }
  }

  private placeNeedle(smooth: boolean): void {
    this.needle.classList.toggle("smooth", smooth);
    this.needle.style.left = `${this.value}%`;
    this.track.setAttribute("aria-valuenow", String(Math.round(this.value)));
  }

  /** A pointer position from the server (someone else dragging). */
  remotePointer(v: number): void {
    if (this.dragging) return;
    this.value = v;
    this.placeNeedle(true);
  }

  update(s: ScaleState): void {
    const prev = this.state;
    this.state = s;
    this.endL.textContent = s.left;
    this.endR.textContent = s.right;
    this.el.dataset.tone = s.tone;
    this.el.classList.toggle("movable", s.movable);
    this.nudge.hidden = !s.movable;
    this.hint.hidden = !s.movable;
    this.track.tabIndex = s.movable ? 0 : -1;
    this.track.setAttribute("aria-readonly", String(!s.movable));
    if (!this.dragging) {
      this.value = s.pointer;
      this.placeNeedle(!!prev);
    }
    if (s.target === null) {
      this.bands.hidden = true;
      this.el.classList.remove("revealing", "revealed");
    } else {
      this.bands.hidden = false;
      const w = BANDS[2] * 2;
      this.bands.style.left = `${s.target - BANDS[2]}%`;
      this.bands.style.width = `${w}%`;
      const widths = [BANDS[2] - BANDS[1], BANDS[1] - BANDS[0], BANDS[0] * 2, BANDS[1] - BANDS[0], BANDS[2] - BANDS[1]];
      [...this.bands.children].forEach((c, i) => ((c as HTMLElement).style.width = `${(widths[i] / w) * 100}%`));
    }
    if (s.reveal) this.playReveal(s.points ?? 0);
    else if (s.points === null) {
      this.pop.textContent = "";
      this.pop.className = "pop";
    }
  }

  private playReveal(points: number): void {
    this.el.classList.remove("revealing", "revealed");
    void this.el.offsetWidth;
    this.el.classList.add("revealing");
    playSweep();
    this.pop.textContent = points > 0 ? `+${points}` : "0";
    this.pop.className = `pop p${points}`;
    setTimeout(() => {
      this.el.classList.remove("revealing");
      this.el.classList.add("revealed");
    }, 1700);
  }
}

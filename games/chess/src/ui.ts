// Small DOM helpers. Elements are built in code; nothing sets inline style attributes, which the
// Content-Security-Policy forbids (properties set through element.style are fine).
import { sprite, type PieceColor, type PieceType } from "./sprites";

type Child = Node | string | number | null | undefined | false;
type Attrs = Record<string, unknown> | null;

export function h<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Attrs = null, ...kids: Child[]): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs ?? {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2), v as EventListener);
    else if (k === "class") el.className = String(v);
    else if (k === "text") el.textContent = String(v);
    else if (k === "value") (el as HTMLInputElement).value = String(v);
    else if (k === "checked") (el as HTMLInputElement).checked = Boolean(v);
    else if (k === "disabled") (el as HTMLButtonElement).disabled = Boolean(v);
    else el.setAttribute(k, v === true ? "" : String(v));
  }
  for (const kid of kids) if (kid !== null && kid !== undefined && kid !== false) el.append(typeof kid === "number" ? String(kid) : kid);
  return el;
}

export const clear = (el: Element) => { while (el.firstChild) el.firstChild.remove(); };

/** A piece as a small crisp image, `scale` screen pixels per art pixel. */
export function pieceIcon(type: PieceType, color: PieceColor, scale = 2, label?: string): HTMLCanvasElement {
  const c = document.createElement("canvas");
  const dpr = Math.max(1, Math.round(window.devicePixelRatio || 1));
  c.width = c.height = 16 * scale * dpr;
  c.className = "piece-icon";
  c.style.width = c.style.height = `${16 * scale}px`;
  const ctx = c.getContext("2d")!;
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(sprite(type, color), 0, 0, c.width, c.height);
  if (label) { c.setAttribute("role", "img"); c.setAttribute("aria-label", label); } else c.setAttribute("aria-hidden", "true");
  return c;
}

let toastTimer: ReturnType<typeof setTimeout> | null = null;
/** A short message at the bottom of the screen. */
export function toast(text: string, kind: "info" | "error" = "info"): void {
  let el = document.getElementById("toast");
  if (!el) { el = h("div", { id: "toast", role: "status", "aria-live": "polite" }); document.body.append(el); }
  el.textContent = text;
  el.className = `show ${kind}`;
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el!.className = ""; }, 3500);
}

export function when(ms: number): string {
  const d = new Date(ms);
  const now = Date.now();
  if (now - ms < 60_000) return "just now";
  if (now - ms < 3600_000) return `${Math.floor((now - ms) / 60_000)} min ago`;
  if (now - ms < 86400_000) return `${Math.floor((now - ms) / 3600_000)} h ago`;
  return d.toLocaleDateString(undefined, { day: "numeric", month: "short", year: d.getFullYear() === new Date().getFullYear() ? undefined : "numeric" });
}

/** Copies text, falling back to selecting it for the player. */
export async function copy(text: string): Promise<boolean> {
  try { await navigator.clipboard.writeText(text); return true; } catch { return false; }
}

/** Replaces an element's children, skipping empty ones. */
export function put(el: Element, ...kids: Child[]): void {
  el.replaceChildren(...kids.filter((k): k is Node | string | number => k !== null && k !== undefined && k !== false).map((k) => (typeof k === "number" ? String(k) : k)));
}

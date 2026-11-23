// The page's line to its room: one WebSocket that reconnects by itself (after a drop, a sleeping
// phone or a refresh) and says hello with the seat this device saved, so the player gets the same
// seat and the current state back.

export type ServerMessage =
  | { t: "welcome"; you: string | null }
  | { t: "seat"; pid: string; token: string }
  | { t: "state"; view: import("../engine/game").View }
  | { t: "pointer"; value: number; by: string }
  | { t: "error"; message: string }
  | { t: "removed" }
  | { t: "gone" }
  | { t: "pong" };

export interface Seat { pid: string; token: string }

const seatKey = (code: string): string => `kvardinn.seat.${code}`;

export function loadSeat(code: string): Seat | null {
  try {
    const s = JSON.parse(localStorage.getItem(seatKey(code)) ?? "null");
    return s && typeof s.pid === "string" && typeof s.token === "string" ? s : null;
  } catch {
    return null;
  }
}

export function saveSeat(code: string, seat: Seat | null): void {
  try {
    if (seat) localStorage.setItem(seatKey(code), JSON.stringify(seat));
    else localStorage.removeItem(seatKey(code));
  } catch {
    /* private mode: the seat lasts as long as the page */
  }
}

export class Connection {
  private ws: WebSocket | null = null;
  private retry = 0;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private ping: ReturnType<typeof setInterval> | null = null;
  private stopped = false;
  connected = false;

  constructor(
    private readonly code: string,
    private readonly screen: boolean,
    private readonly onMessage: (m: ServerMessage) => void,
    private readonly onStatus: (connected: boolean) => void,
  ) {
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible" && !this.connected && !this.stopped) this.open();
    });
    window.addEventListener("online", () => {
      if (!this.connected && !this.stopped) this.open();
    });
  }

  open(): void {
    if (this.stopped) return;
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) return;
    const url = new URL(`ws/${this.code}`, location.href);
    url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
    url.hash = "";
    url.search = "";
    const ws = new WebSocket(url);
    this.ws = ws;
    ws.onopen = () => {
      this.retry = 0;
      this.connected = true;
      this.onStatus(true);
      const seat = loadSeat(this.code);
      this.send({ t: "hello", pid: seat?.pid, token: seat?.token, screen: this.screen });
      if (this.ping) clearInterval(this.ping);
      this.ping = setInterval(() => this.send({ t: "ping" }), 25000);
    };
    ws.onmessage = (e) => {
      try {
        if (this.ws !== ws) return;
        const m = JSON.parse(String(e.data)) as ServerMessage;
        if (m.t === "gone") this.stop();
        this.onMessage(m);
      } catch {
        /* ignore */
      }
    };
    ws.onclose = (e) => {
      if (this.ws !== ws) return;
      this.connected = false;
      if (this.ping) clearInterval(this.ping);
      this.onStatus(false);
      if (e.code === 4404) {
        this.stop();
        this.onMessage({ t: "gone" });
        return;
      }
      if (!this.stopped) {
        const delay = Math.min(5000, 400 * 2 ** this.retry++);
        this.timer = setTimeout(() => this.open(), delay);
      }
    };
  }

  /** Ends this connection for good: no more messages, no reconnecting. */
  stop(): void {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
    if (this.ping) clearInterval(this.ping);
    const ws = this.ws;
    this.ws = null;
    if (ws) {
      ws.onmessage = null;
      ws.onclose = null;
      try {
        ws.close(1000, "bye");
      } catch {
        /* never opened */
      }
    }
  }

  send(msg: unknown): boolean {
    if (this.ws?.readyState !== WebSocket.OPEN) return false;
    this.ws.send(JSON.stringify(msg));
    return true;
  }
}

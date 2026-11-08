// The browser's side of the Worker's API (worker/api.ts) and of a game's live connection.
import type { Action, Challenge, Contact, GameView, LiveMessage, Lobby, Me } from "./shared/protocol";

const base = () => new URL(".", document.baseURI);
const url = (path: string) => new URL(path, base()).toString();

export class ApiError extends Error {
  constructor(message: string, readonly status: number, readonly body: Record<string, unknown> = {}) { super(message); }
}

async function call<T>(path: string, method = "GET", body?: unknown): Promise<T> {
  let res: Response;
  try {
    res = await fetch(url(`api/${path}`), {
      method,
      credentials: "same-origin",
      headers: body === undefined ? {} : { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError("Can't reach the server. Are you online?", 0);
  }
  let data: Record<string, unknown> = {};
  try { data = await res.json(); } catch { /* not JSON */ }
  if (!res.ok) throw new ApiError(typeof data.error === "string" ? data.error : `Server error ${res.status}`, res.status, data);
  return data as T;
}

export const api = {
  me: () => call<Me>("me"),
  rename: (name: string) => call<{ user: Me["user"] }>("me/name", "POST", { name }),
  lobby: () => call<Lobby>("lobby"),
  challenge: (email: string, color: string) => call<{ challenge: Challenge; emailed: boolean; link: string }>("challenges", "POST", { email, color }),
  getChallenge: (id: string) => call<{ challenge: Challenge }>(`challenges/${id}`),
  answer: (id: string, what: "accept" | "decline" | "cancel") => call<{ game?: GameView }>(`challenges/${id}/${what}`, "POST", {}),
  addContact: (email: string, name?: string) => call<{ contacts: Contact[] }>("contacts", "POST", { email, name }),
  removeContact: (email: string) => call<{ contacts: Contact[] }>("contacts/remove", "POST", { email }),
  history: (before?: number) => call<{ games: GameView[] }>(`games${before ? `?before=${before}` : ""}`),
  game: (id: string) => call<{ game: GameView }>(`games/${id}`),
  act: (id: string, action: Action) => call<{ game: GameView }>(`games/${id}/action`, "POST", action),
  saveComputer: (level: number, color: string, moves: string[], resigned: boolean) =>
    call<{ game: GameView }>("games/computer", "POST", { level, color, moves, resigned }),
  logout: () => fetch(url("auth/logout"), { method: "POST", credentials: "same-origin", headers: { "Content-Type": "application/json" }, body: "{}" }),
  loginUrl: (provider: string, back: string) =>
    provider === "dev" ? url(`auth/dev?return=${encodeURIComponent(back)}`) : url(`auth/login/${provider}?return=${encodeURIComponent(back)}`),
};

/**
 * The live connection to an online game: calls `onGame` with the whole game whenever it changes,
 * and reconnects (with back-off) when the connection drops, until closed.
 */
export class Live {
  private ws: WebSocket | null = null;
  private closed = false;
  private retry = 500;
  private ping: ReturnType<typeof setInterval> | null = null;

  constructor(private id: string, private onGame: (g: GameView) => void, private onStatus: (online: boolean) => void) {
    this.open();
  }

  private open(): void {
    if (this.closed) return;
    const u = new URL(`api/games/${this.id}/live`, base());
    u.protocol = u.protocol === "https:" ? "wss:" : "ws:";
    const ws = new WebSocket(u.toString());
    this.ws = ws;
    ws.onopen = () => {
      this.retry = 500;
      this.onStatus(true);
      this.ping = setInterval(() => { try { ws.send("ping"); } catch { /* closing */ } }, 25000);
    };
    ws.onmessage = (e) => {
      let msg: LiveMessage;
      try { msg = JSON.parse(String(e.data)); } catch { return; }
      if (msg.t === "state") this.onGame(msg.game);
    };
    ws.onclose = () => {
      if (this.ping) clearInterval(this.ping);
      this.onStatus(false);
      if (this.closed) return;
      setTimeout(() => this.open(), this.retry);
      this.retry = Math.min(15000, this.retry * 2);
    };
  }

  close(): void {
    this.closed = true;
    if (this.ping) clearInterval(this.ping);
    this.ws?.close();
  }
}

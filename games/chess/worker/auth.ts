// Signing in for Gambit: icelander.net's one sign-in (the games are part of the site), through icelander.net's login service (the games
// hub's docs/SIGN-IN.md; icelander.net docs/accounts.md), with the shared library vendored in vendor/icelander-auth.
// Gambit has no OAuth code of its own any more: Google and GitHub are the login service's.
//
//   GET  {BASE}/auth/login/{provider}?return=PATH   → the host's sign-in (/auth/sign-in), which comes back to PATH
//   POST {BASE}/auth/logout                          signs out of icelander.net
//   GET  {BASE}/auth/dev?email=…&name=…[&format=token]   only when DEV_LOGIN is "1", on localhost (local development)
//
// The cookie is the host's games_session; a desktop build talking to a dev server sends the same value as
// "Authorization: Bearer". A person is their address: Gambit's own users table (games, contacts, history) is keyed
// by it, so the first of the person's addresses Gambit already knows is the one they play as.
import { createAuth, type AuthEnv as SharedAuthEnv } from "../../../vendor/icelander-auth/index.js";
import { BASE, cleanDisplayName, cleanEmail, type User } from "../shared/protocol";
import { upsertUser, userByEmail, type D1Database } from "./db";

export interface AuthEnv extends SharedAuthEnv {
  DB: D1Database;
  DEV_LOGIN?: string;
}

const AUTH = createAuth({ app: "site", cookie: "site_session", home: `${BASE}/`, implicitRole: "reader", rolePrefixes: ["games"], bearer: true });

/** The library's env: DEV_LOGIN "1" turns on its stand-in sign-in (which works on localhost only). */
const shared = (env: AuthEnv): AuthEnv => (env.DEV_LOGIN === "1" ? { ...env, DEV_SIGN_IN: "true" } : env);

/** The sign-in methods the game offers: Google and GitHub through the login service, and the stand-in locally. */
export function providers(env: AuthEnv): string[] {
  return [...(AUTH.configured(env) ? ["google", "github"] : []), ...(env.DEV_LOGIN === "1" ? ["dev"] : [])];
}

/** Where profile pictures may come from: the providers' own image hosts, over HTTPS. */
export const PICTURE_HOSTS = ["lh3.googleusercontent.com", "avatars.githubusercontent.com"];
export function safePicture(x: unknown): string | null {
  if (typeof x !== "string" || x.length > 1000) return null;
  try {
    const u = new URL(x);
    return u.protocol === "https:" && PICTURE_HOSTS.includes(u.hostname) ? u.toString() : null;
  } catch {
    return null;
  }
}

/** A return path inside the game, or the game's front page. */
export function safeReturn(x: string | null): string {
  if (x && x.startsWith(`${BASE}/`) && !x.startsWith("//") && !/[\\\r\n]/.test(x)) return x;
  return `${BASE}/`;
}

/** Gambit's sign-in check for the page (index.ts): every game under icelander.net/games needs a sign-in. */
export const requirePlayer = (req: Request, env: AuthEnv) => AUTH.requireRole(req, shared(env), "games:play");

/**
 * The signed-in user as Gambit knows them (its own users row), or null. Asked of the login service on every
 * request; Gambit's row is made, or its name and picture refreshed, only when something changed.
 */
export async function currentUser(req: Request, env: AuthEnv): Promise<User | null> {
  const person = await AUTH.currentUser(req, shared(env));
  const primary = cleanEmail(person?.email);
  if (!person || !primary) return null;
  let email = primary;
  for (const e of person.emails ?? []) {
    const known = cleanEmail(e);
    if (known && (await userByEmail(env.DB, known))) {
      email = known;
      break;
    }
  }
  const name = cleanDisplayName(person.name);
  const picture = safePicture(person.picture);
  const existing = await userByEmail(env.DB, email);
  if (existing && existing.name === name && (!picture || existing.picture === picture)) return existing;
  return upsertUser(env.DB, email, name, picture, Date.now());
}

const redirect = (location: string) => new Response(null, { status: 302, headers: { Location: location, "Cache-Control": "no-store" } });

/** The library's route on this host, for one of Gambit's own sign-in addresses. */
function asShared(req: Request, url: URL, path: string): Request {
  const to = new URL(path, url);
  to.search = url.search;
  return new Request(to, req);
}

export async function handleAuth(req: Request, env: AuthEnv, url: URL): Promise<Response | null> {
  const rest = url.pathname.slice(`${BASE}/auth/`.length);
  const [action] = rest.split("/");

  if (action === "logout" && req.method === "POST") {
    // A desktop build's stand-in token: nothing to end, it just forgets it.
    if ((req.headers.get("Authorization") ?? "").startsWith("Bearer dev.")) return new Response(JSON.stringify({ ok: true }), { headers: { "Content-Type": "application/json" } });
    return (await AUTH.handle(asShared(req, url, "/auth/sign-out"), shared(env)))!;
  }
  if (action === "dev" && req.method === "GET") {
    if (env.DEV_LOGIN !== "1") return new Response("Not found", { status: 404 });
    const to = new URL("/auth/dev", url);
    to.search = url.search;
    to.searchParams.set("return", safeReturn(url.searchParams.get("return")));
    return (await AUTH.handle(new Request(to, req), shared(env)))!;
  }
  // Signing in, and the old OAuth callbacks (a bookmark or a page from before): the host's sign-in.
  if ((action === "login" || action === "callback") && req.method === "GET") {
    return redirect(AUTH.signInPath(safeReturn(url.searchParams.get("return"))));
  }
  return null;
}

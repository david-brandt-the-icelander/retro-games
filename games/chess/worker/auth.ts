// Sign-in with Google or GitHub (OAuth 2.0 authorization code flow with PKCE), and the session cookie.
//
//   GET  {BASE}/auth/login/{provider}?return=PATH   → redirect to the provider
//   GET  {BASE}/auth/callback/{provider}            ← the provider's redirect; sets the session cookie
//   POST {BASE}/auth/logout
//   GET  {BASE}/auth/dev?email=…&name=…              only when DEV_LOGIN is "1" (local development)
//
// A user is their verified email address: signing in with Google and with GitHub under the same
// address is the same user. Only a SHA-256 hash of each session token is stored.
import { BASE, cleanDisplayName, cleanEmail, type User } from "../shared/protocol";
import { createSession, deleteSession, sessionUser, upsertUser, type D1Database } from "./db";

export interface AuthEnv {
  DB: D1Database;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  GITHUB_CLIENT_ID?: string;
  GITHUB_CLIENT_SECRET?: string;
  DEV_LOGIN?: string;
}

const SESSION_COOKIE = "chess_session";
const OAUTH_COOKIE = "chess_oauth";
const SESSION_MS = 60 * 24 * 3600 * 1000;
const UA = "icelander-chess";

interface Provider {
  authorize: string;
  token: string;
  scope: string;
  id: (env: AuthEnv) => string | undefined;
  secret: (env: AuthEnv) => string | undefined;
  /** The user's verified email and name, from the access token. */
  profile: (token: string) => Promise<{ email: string; name: string; picture: string | null } | null>;
}

const PROVIDERS: Record<string, Provider> = {
  google: {
    authorize: "https://accounts.google.com/o/oauth2/v2/auth",
    token: "https://oauth2.googleapis.com/token",
    scope: "openid email profile",
    id: (e) => e.GOOGLE_CLIENT_ID,
    secret: (e) => e.GOOGLE_CLIENT_SECRET,
    async profile(token) {
      const res = await fetch("https://openidconnect.googleapis.com/v1/userinfo", { headers: { Authorization: `Bearer ${token}` } });
      if (!res.ok) return null;
      const p = (await res.json()) as { email?: string; email_verified?: boolean; name?: string; picture?: string };
      const email = cleanEmail(p.email);
      return email && p.email_verified ? { email, name: cleanDisplayName(p.name), picture: safePicture(p.picture) } : null;
    },
  },
  github: {
    authorize: "https://github.com/login/oauth/authorize",
    token: "https://github.com/login/oauth/access_token",
    scope: "read:user user:email",
    id: (e) => e.GITHUB_CLIENT_ID,
    secret: (e) => e.GITHUB_CLIENT_SECRET,
    async profile(token) {
      const h = { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json", "User-Agent": UA };
      const [u, em] = await Promise.all([fetch("https://api.github.com/user", { headers: h }), fetch("https://api.github.com/user/emails", { headers: h })]);
      if (!u.ok || !em.ok) return null;
      const user = (await u.json()) as { name?: string | null; login?: string; avatar_url?: string };
      const emails = (await em.json()) as { email: string; primary: boolean; verified: boolean }[];
      const best = emails.find((e) => e.primary && e.verified) ?? emails.find((e) => e.verified);
      const email = cleanEmail(best?.email);
      return email ? { email, name: cleanDisplayName(user.name || user.login), picture: safePicture(user.avatar_url) } : null;
    },
  },
};

/** The sign-in methods that are set up on this deployment. */
export function providers(env: AuthEnv): string[] {
  const list = Object.keys(PROVIDERS).filter((p) => PROVIDERS[p].id(env) && PROVIDERS[p].secret(env));
  if (env.DEV_LOGIN === "1") list.push("dev");
  return list;
}

// ── Small helpers ──

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

const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const randomToken = (n = 32) => b64url(crypto.getRandomValues(new Uint8Array(n)));
export async function sha256(text: string): Promise<string> {
  return b64url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text))));
}

export function readCookie(req: Request, name: string): string | null {
  const header = req.headers.get("Cookie") ?? "";
  for (const part of header.split(";")) {
    const i = part.indexOf("=");
    if (i > 0 && part.slice(0, i).trim() === name) return decodeURIComponent(part.slice(i + 1).trim());
  }
  return null;
}

function cookie(name: string, value: string, path: string, maxAge: number, secure: boolean): string {
  return `${name}=${encodeURIComponent(value)}; Path=${path}; Max-Age=${maxAge}; HttpOnly; SameSite=Lax${secure ? "; Secure" : ""}`;
}

const isSecure = (url: URL) => url.protocol === "https:";

/** A return path inside the game, or the game's front page. */
export function safeReturn(x: string | null): string {
  if (x && x.startsWith(`${BASE}/`) && !x.startsWith("//") && !/[\\\r\n]/.test(x)) return x;
  return `${BASE}/`;
}

function redirect(location: string, cookies: string[] = []): Response {
  const headers = new Headers({ Location: location, "Cache-Control": "no-store" });
  for (const c of cookies) headers.append("Set-Cookie", c);
  return new Response(null, { status: 302, headers });
}

// ── Sessions ──

/**
 * The signed-in user: from the session cookie (the web build, same origin), or from an
 * "Authorization: Bearer" header with the same token (a desktop build talking to a dev server).
 */
export async function currentUser(req: Request, env: AuthEnv): Promise<User | null> {
  const bearer = /^Bearer (\S+)$/.exec(req.headers.get("Authorization") ?? "")?.[1];
  const token = bearer ?? readCookie(req, SESSION_COOKIE);
  if (!token || token.length > 100) return null;
  return sessionUser(env.DB, await sha256(token), Date.now());
}

async function startSession(env: AuthEnv, url: URL, email: string, name: string, picture: string | null, back: string, asToken = false): Promise<Response> {
  const now = Date.now();
  const user = await upsertUser(env.DB, email, name, picture, now);
  const token = randomToken();
  await createSession(env.DB, await sha256(token), user.id, now, SESSION_MS);
  if (asToken) return new Response(JSON.stringify({ token, user }), { headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
  return redirect(back, [
    cookie(SESSION_COOKIE, token, BASE, SESSION_MS / 1000, isSecure(url)),
    cookie(OAUTH_COOKIE, "", `${BASE}/auth`, 0, isSecure(url)),
  ]);
}

// ── The routes ──

export async function handleAuth(req: Request, env: AuthEnv, url: URL): Promise<Response | null> {
  const rest = url.pathname.slice(`${BASE}/auth/`.length);
  const [action, name] = rest.split("/");

  if (action === "logout" && req.method === "POST") {
    const token = readCookie(req, SESSION_COOKIE);
    if (token) await deleteSession(env.DB, await sha256(token));
    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json", "Set-Cookie": cookie(SESSION_COOKIE, "", BASE, 0, isSecure(url)) },
    });
  }

  if (action === "dev" && req.method === "GET") {
    if (env.DEV_LOGIN !== "1") return new Response("Not found", { status: 404 });
    const email = cleanEmail(url.searchParams.get("email"));
    if (!email) return new Response("Give ?email=", { status: 400 });
    // ?format=token answers with the token instead of a cookie, for a desktop build or the Godot editor.
    return startSession(env, url, email, cleanDisplayName(url.searchParams.get("name")), safePicture(url.searchParams.get("picture")),
      safeReturn(url.searchParams.get("return")), url.searchParams.get("format") === "token");
  }

  const p = PROVIDERS[name ?? ""];
  if (!p || req.method !== "GET") return null;
  const clientId = p.id(env), secret = p.secret(env);
  if (!clientId || !secret) return new Response(`Sign-in with ${name} isn't set up here.`, { status: 404 });
  const callback = `${url.origin}${BASE}/auth/callback/${name}`;

  if (action === "login") {
    const state = randomToken(16);
    const verifier = randomToken(32);
    const challenge = await sha256(verifier);
    const back = safeReturn(url.searchParams.get("return"));
    const q = new URLSearchParams({
      client_id: clientId, redirect_uri: callback, response_type: "code", scope: p.scope, state,
      code_challenge: challenge, code_challenge_method: "S256",
    });
    if (name === "google") q.set("prompt", "select_account");
    const value = [state, verifier, name, back].join("|");
    return redirect(`${p.authorize}?${q}`, [cookie(OAUTH_COOKIE, value, `${BASE}/auth`, 600, isSecure(url))]);
  }

  if (action === "callback") {
    const saved = (readCookie(req, OAUTH_COOKIE) ?? "").split("|");
    const [state, verifier, provider, back] = saved;
    const code = url.searchParams.get("code");
    if (!code || !state || state !== url.searchParams.get("state") || provider !== name) {
      return redirect(`${BASE}/#signin-failed`);
    }
    const res = await fetch(p.token, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json", "User-Agent": UA },
      body: new URLSearchParams({ client_id: clientId, client_secret: secret, code, redirect_uri: callback, grant_type: "authorization_code", code_verifier: verifier }),
    });
    const tok = res.ok ? ((await res.json()) as { access_token?: string }) : {};
    const profile = tok.access_token ? await p.profile(tok.access_token) : null;
    if (!profile) return redirect(`${BASE}/#signin-failed`);
    return startSession(env, url, profile.email, profile.name, profile.picture, safeReturn(back ?? null));
  }
  return null;
}

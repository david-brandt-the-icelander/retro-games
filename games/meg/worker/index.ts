// The MEG Worker: serves the static game, and only to someone signed in to icelander.net.
// The game keeps its progress and high scores in the player's browser, so there is no API and no database.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { ASSETS: Fetcher }

export const PATH = "/games/retro/meg";

/**
 * Every game under icelander.net/games needs a sign-in (the games hub's docs/SIGN-IN.md): the site's one cookie, site_session,
 * checked with icelander.net's login service through the ACCOUNTS binding. The site's Worker answers /auth/….
 */
const AUTH = createAuth({ app: "site", cookie: "site_session", home: "/games/", implicitRole: "reader", rolePrefixes: ["games"] });

/** The game's page itself; its script and stylesheet come straight from the assets. */
const isPage = (path: string) => path === `${PATH}/` || path === `${PATH}/index.html`;

/** The page, for anyone signed in; anyone else goes to sign in and comes back. */
async function gamePage(req: Request, env: Env): Promise<Response> {
  const { response } = await AUTH.requireRole(req, env, "games:play");
  if (response) return response;
  const page = await env.ASSETS.fetch(req);
  const out = new Response(page.body, page);
  out.headers.set("Cache-Control", "private, no-cache");
  return out;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === PATH) return Response.redirect(`${url.origin}${PATH}/${url.search}`, 301);
    if (isPage(url.pathname)) return gamePage(req, env);
    return env.ASSETS.fetch(req);
  },
};

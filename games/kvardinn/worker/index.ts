// The Kvarðinn Worker: worker/handler.ts answers every request (behind icelander.net's sign-in and
// the invite-only role games:kvardinn); worker/room.ts is the Durable Object that holds each room.
import { handle, type Env } from "./handler";
import { Room } from "./room";

export { Room };

export default {
  fetch(req: Request, env: Env): Promise<Response> {
    return handle(req, env);
  },
};

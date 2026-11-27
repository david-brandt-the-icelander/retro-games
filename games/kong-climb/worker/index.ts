// The Kong Climb Worker: worker/handler.ts answers every request, behind icelander.net's sign-in and
// the invite-only role games:recreations.
import { handle, type Env } from "./handler";

export default {
  fetch(req: Request, env: Env): Promise<Response> {
    return handle(req, env);
  },
};

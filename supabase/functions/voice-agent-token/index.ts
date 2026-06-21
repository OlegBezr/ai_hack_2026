// POST /functions/v1/voice-agent-token
// Body: none.
// Verifies the caller is a signed-in user, then mints a short-lived Deepgram
// token the browser uses to open the Voice Agent WebSocket. The long-lived
// DEEPGRAM_KEY never leaves the server. Returns { token, expires_in }.
//
// CORS, per-request Sentry scope, and error→Response shaping all live in
// serveWithSentry (../_shared/sentry.ts) — this file is just the business logic.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";
import { grantVoiceToken } from "../_shared/deepgram.ts";
import { breadcrumb, jsonResponse, serveWithSentry, setUser } from "../_shared/sentry.ts";

serveWithSentry("voice-agent-token", async (req) => {
  const { user } = await getAuthenticatedUser(req);
  setUser(user.id);
  breadcrumb("voice", "token request", { user_id: user.id });

  const { token, expiresIn } = await grantVoiceToken();

  return jsonResponse({ token, expires_in: expiresIn });
});

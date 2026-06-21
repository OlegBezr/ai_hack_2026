// Template edge function — copy this as the starting point for new functions.
// serveWithSentry (../_shared/sentry.ts) handles CORS, a per-request Sentry
// scope, error→Response shaping, and flushing; the callback is just your logic.
// Verify locally with:
//   supabase functions serve hello-world
//   curl -i --request POST http://localhost:54321/functions/v1/hello-world \
//     --header "Content-Type: application/json" --data '{"name":"world"}'
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { jsonResponse, serveWithSentry } from "../_shared/sentry.ts";

serveWithSentry("hello-world", async (req) => {
  const { name } = await req.json().catch(() => ({ name: "world" }));
  return jsonResponse({ message: `Hello ${name ?? "world"}!` });
});

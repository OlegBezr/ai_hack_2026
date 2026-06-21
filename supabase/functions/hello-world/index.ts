// Template edge function. Verify locally with:
//   supabase functions serve hello-world
//   curl -i --request POST http://localhost:54321/functions/v1/hello-world \
//     --header "Content-Type: application/json" --data '{"name":"world"}'
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const { name } = await req.json().catch(() => ({ name: "world" }));

  return new Response(
    JSON.stringify({ message: `Hello ${name ?? "world"}!` }),
    {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});

/*
 * Development-only auth email hook.
 * Captures the Supabase "send email" webhook payload and prints the OTP code to
 * the console, so you never need a real mailbox while developing locally.
 *
 * Run:  deno run --allow-net tools/dev-email-auth-hook/main.ts
 * Wired up via [auth.hook.send_email] in supabase/config.toml.
 * Output also appears in the supabase_edge_runtime_* docker container logs.
 */

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const port = 4000;

Deno.serve({ port }, async (req) => {
  if (req.method !== "POST") {
    return new Response("not allowed", { status: 400 });
  }

  const payload = await req.text();
  const headers = Object.fromEntries(req.headers);

  // Must match the secret in supabase/config.toml -> [auth.hook.send_email].
  const wh = new Webhook(
    "VmZGNUpZRlZzbGFDS08zc3pUOVlaVjBraGRDZFJ5ZVBzN09QWkVjMjFGOD0K",
  );

  const { user, email_data } = wh.verify(payload, headers) as {
    user: {
      email: string;
    };
    email_data: {
      token: string;
      token_hash: string;
      redirect_to: string;
      email_action_type: string;
      site_url: string;
      token_new: string;
      token_hash_new: string;
    };
  };

  console.log({ email_data, user });
  console.log(`EMAIL OTP for ${user.email}: ${email_data.token}`);

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: new Headers({ "Content-Type": "application/json" }),
  });
});

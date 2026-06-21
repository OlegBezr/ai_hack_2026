// Supabase "Send Email" auth hook.
//
// When this hook is enabled, GoTrue calls us INSTEAD of its own mailer for every
// auth email (OTP, magic link, recovery, ...). That has two effects we want:
//   1. We're off Supabase's shared default mailer, so its brutal ~2–3/hr limit
//      no longer applies — the only cap left is auth.rate_limit.email_sent.
//   2. We control delivery. Here, delivery == "write the code to the logs", so a
//      throttled / unconfigured mailbox never blocks login. Read the code from
//      the Edge Function logs (dashboard → Logs → Edge Functions, or it rides
//      into Sentry via the console-logging integration).
//
// SECURITY: logging OTPs means anyone with log access can sign in as any user.
// This is a hackathon-grade fallback — do NOT ship it to real users. The real
// fix for production is custom SMTP (then delete the console.log below).
//
// GoTrue authenticates the call with a standardwebhooks signature (NOT a user
// JWT) — so this function MUST run with verify_jwt = false (see config.toml).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Webhook } from "standardwebhooks";
import { breadcrumb, jsonResponse, serveWithSentry } from "../_shared/sentry.ts";
import type { ErrorResponse } from "../_shared/auth.ts";

interface SendEmailPayload {
  user: { id?: string; email: string };
  email_data: {
    token: string;
    token_hash: string;
    redirect_to: string;
    email_action_type: string;
    site_url: string;
    token_new: string;
    token_hash_new: string;
  };
}

// The hook secret GoTrue signs with, stored as "v1,whsec_<base64>". In prod set
// SEND_EMAIL_HOOK_SECRET to the value the dashboard generates when you create the
// hook. Locally it falls back to the dev secret in config.toml so there's zero
// setup — mirroring how the Sentry wrapper no-ops without a DSN.
const LOCAL_DEV_SECRET = "v1,whsec_VmZGNUpZRlZzbGFDS08zc3pUOVlaVjBraGRDZFJ5ZVBzN09QWkVjMjFGOD0K";

function webhook(): Webhook {
  const raw = Deno.env.get("SEND_EMAIL_HOOK_SECRET") || LOCAL_DEV_SECRET;
  // standardwebhooks wants the bare base64 secret, without the "v1,whsec_" prefix.
  return new Webhook(raw.replace(/^v1,whsec_/, ""));
}

serveWithSentry("auth-send-email", (req) => {
  return handle(req);
});

async function handle(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    throw { status: 405, error: "Method not allowed" } as ErrorResponse;
  }

  const payload = await req.text();
  const headers = Object.fromEntries(req.headers);

  let data: SendEmailPayload;
  try {
    data = webhook().verify(payload, headers) as SendEmailPayload;
  } catch (_err) {
    // Bad / missing signature => not a genuine GoTrue call. Reject quietly (4xx,
    // so serveWithSentry logs a warning, not a paging 5xx).
    throw { status: 401, error: "Invalid webhook signature" } as ErrorResponse;
  }

  const { user, email_data } = data;
  breadcrumb("auth", "send_email hook", { action: email_data.email_action_type });

  // ── Delivery channel: the logs ─────────────────────────────────────────────
  // console.log is the primary read-from-logs path (Supabase Edge Function logs).
  console.log(
    `AUTH OTP for ${user.email}: ${email_data.token} (${email_data.email_action_type})`,
  );

  // ── Optional real send goes here ───────────────────────────────────────────
  // If you later add Gmail/Brevo SMTP, attempt the send in a try/catch and
  // swallow failures: the code is already logged above, so login still works.

  // 200 with an empty body tells GoTrue the email was handled — the user moves
  // straight to the code-entry screen with no error shown.
  return jsonResponse({});
}

// Shared Sentry setup for every edge function — the single place that knows
// about Sentry, so no function (or shared module) hardcodes its own wiring.
//
// Why a shared wrapper and not a per-function init: the Deno SDK does NOT
// instrument `Deno.serve`, so there is no automatic per-request scope. Supabase
// also reuses one isolate across many requests, so anything written to the
// global scope (tags, user, breadcrumbs) bleeds between unrelated requests. We
// therefore run every request body inside `Sentry.withScope`, mutate only that
// forked scope, capture exceptions against it, and flush before the isolate can
// freeze. (withScope is what prevents bleed — not disabling integrations.)
//
// Capabilities wired here:
//   - errors with per-request scope, tags, user, request context
//   - Structured Logs (Sentry.logger.* + console.* piped via consoleLogging)
//   - performance spans + custom measurements (withSpan / measure)
//   - PII scrubbing (beforeSend) and attachments on captured errors
//
// Config via env — all optional. Without SENTRY_DSN the SDK silently no-ops, so
// local dev needs zero setup and nothing is sent.
//   SENTRY_DSN                  enable reporting
//   SENTRY_ENVIRONMENT          e.g. production / staging  (default "production")
//   SENTRY_RELEASE              release/version string (e.g. git SHA)
//   SENTRY_TRACES_SAMPLE_RATE   0..1 performance tracing  (default 1.0)
// Supabase injects SB_REGION and SB_EXECUTION_ID, which we tag automatically.

import * as Sentry from "@sentry/deno";
import { corsHeaders } from "./cors.ts";
import type { ErrorResponse } from "./auth.ts";

type Level = "fatal" | "error" | "warning" | "info" | "debug";
/** Values allowed on log attributes, span measurements, and tags. */
type Attrs = Record<string, string | number | boolean>;

let _initialized = false;

// Redact secrets that might ride along in headers/extra/context before an event
// leaves the isolate. We control most of what we attach, but this is a backstop.
const SENSITIVE = /(authorization|api[-_]?key|token|secret|password|cookie)/i;

function scrub(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(scrub);
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = SENSITIVE.test(k) ? "[redacted]" : scrub(v);
    }
    return out;
  }
  return value;
}

/** Initialize the SDK once per isolate. Idempotent and safe without a DSN. */
export function initSentry(): void {
  if (_initialized) return;
  _initialized = true;
  Sentry.init({
    dsn: Deno.env.get("SENTRY_DSN"),
    environment: Deno.env.get("SENTRY_ENVIRONMENT") ?? "production",
    release: Deno.env.get("SENTRY_RELEASE") || undefined,
    tracesSampleRate: Number(Deno.env.get("SENTRY_TRACES_SAMPLE_RATE") ?? "1.0"),
    // Structured Logs (Sentry.logger.*). Also mirror console.* into logs so the
    // console.log/error calls already in the code show up without a rewrite.
    enableLogs: true,
    integrations: [
      Sentry.consoleLoggingIntegration({ levels: ["log", "warn", "error"] }),
    ],
    beforeSend(event) {
      if (event.request?.headers) {
        event.request.headers = scrub(event.request.headers) as Record<string, string>;
      }
      if (event.extra) event.extra = scrub(event.extra) as Record<string, unknown>;
      if (event.contexts) {
        event.contexts = scrub(event.contexts) as typeof event.contexts;
      }
      return event;
    },
  });
}

/** JSON response with CORS headers. Shared so every function shapes alike. */
export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isErrorResponse(err: unknown): err is ErrorResponse {
  return !!err && typeof err === "object" && "status" in err && "error" in err;
}

/** Attach the authenticated user to the active (per-request) scope. */
export function setUser(id: string): void {
  Sentry.setUser({ id });
}

/** Set searchable, indexed tags on the active (per-request) scope. */
export function setTags(tags: Attrs): void {
  for (const [k, v] of Object.entries(tags)) Sentry.setTag(k, v);
}

/** Record a numeric metric on the active span — BEST EFFORT only.
 *
 * Verified 2026-06: @sentry/deno does not surface custom span measurements or
 * attributes in the Spans dataset (setMeasurement / setAttribute both come back
 * empty), so do NOT rely on this for charts/alerts. The source of truth for
 * metrics is the structured log emitted alongside each call (logInfo with a
 * `*_ms` / count attribute) — those attributes ARE searchable in the Logs
 * dataset. This stays as a best-effort hook in case the SDK/UI starts surfacing
 * it; every value passed here is also logged. */
export function measure(name: string, value: number, unit = "none"): void {
  Sentry.setMeasurement(name, value, unit);
  Sentry.getActiveSpan()?.setAttribute(name, value);
}

/** Record a breadcrumb on the active (per-request) scope. */
export function breadcrumb(
  category: string,
  message: string,
  data?: Record<string, unknown>,
  level: Level = "info",
): void {
  Sentry.addBreadcrumb({ category, message, data, level });
}

/** Attach a blob (e.g. a raw upstream response) to the active request scope,
 * so it rides along with whatever error is captured next. */
export function attach(filename: string, data: string): void {
  Sentry.getCurrentScope().addAttachment({ filename, data });
}

// --- Structured logs --------------------------------------------------------
// Thin wrappers so call sites depend on this module, not Sentry directly.
export const logInfo = (msg: string, attrs?: Attrs) => Sentry.logger.info(msg, attrs);
export const logWarn = (msg: string, attrs?: Attrs) => Sentry.logger.warn(msg, attrs);
export const logError = (msg: string, attrs?: Attrs) => Sentry.logger.error(msg, attrs);

/** Capture an exception with extra context, tags, and an optional attachment. */
export function captureError(
  err: unknown,
  opts?: {
    context?: Record<string, unknown>;
    tags?: Attrs;
    attachment?: { filename: string; data: string };
  },
): void {
  Sentry.withScope((scope) => {
    if (opts?.context) scope.setContext("detail", opts.context);
    if (opts?.tags) { for (const [k, v] of Object.entries(opts.tags)) scope.setTag(k, v); }
    if (opts?.attachment) {
      scope.addAttachment({
        filename: opts.attachment.filename,
        data: opts.attachment.data,
      });
    }
    Sentry.captureException(err instanceof Error ? err : new Error(String(err)));
  });
}

/**
 * Run `fn` inside a Sentry span and emit start/ok/error breadcrumbs. Use to wrap
 * outbound calls — Midjourney, Deepgram, etc. — so a failure carries a timeline,
 * and so `measure()` calls inside `fn` attach to this span.
 */
export async function withSpan<T>(
  op: string,
  name: string,
  fn: () => Promise<T>,
  data?: Attrs,
): Promise<T> {
  breadcrumb(op, `${name} → start`, data);
  try {
    const out = await Sentry.startSpan({ op, name, attributes: data }, fn);
    breadcrumb(op, `${name} → ok`);
    return out;
  } catch (err) {
    breadcrumb(
      op,
      `${name} → error: ${err instanceof Error ? err.message : String(err)}`,
      undefined,
      "error",
    );
    throw err;
  }
}

type Handler = (req: Request) => Promise<Response>;

/**
 * Wrap a Deno.serve handler with the full Sentry lifecycle so each function
 * carries only its business logic:
 *  - CORS preflight handling,
 *  - one forked scope per request (no cross-request bleed),
 *  - runtime tags (function name, region, execution id) + request context,
 *  - start/finish structured logs with status + duration,
 *  - uniform error shaping: expected client errors (4xx ErrorResponse) pass
 *    through quietly; 5xx ErrorResponses and any unexpected throw are reported
 *    to Sentry and returned as 500,
 *  - flush events AND logs before the edge isolate can freeze.
 */
export function serveWithSentry(name: string, handler: Handler): void {
  initSentry();
  Deno.serve((req) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    const startedAt = Date.now();
    return Sentry.withScope(async (scope) => {
      scope.setTag("function", name);
      scope.setTag("region", Deno.env.get("SB_REGION") ?? "unknown");
      scope.setTag("execution_id", Deno.env.get("SB_EXECUTION_ID") ?? "unknown");
      scope.setContext("request", { method: req.method, url: req.url });
      logInfo("request started", { function: name, method: req.method });

      let status = 200;
      try {
        const res = await handler(req);
        status = res.status;
        return res;
      } catch (err) {
        if (isErrorResponse(err)) {
          status = err.status;
          // 4xx are expected client errors — don't page on them. Report 5xx.
          if (err.status >= 500) {
            logError("request failed", { function: name, status: err.status, error: err.error });
            captureError(new Error(err.error), { tags: { status: err.status } });
          } else {
            logWarn("request rejected", { function: name, status: err.status, error: err.error });
          }
          return jsonResponse({ error: err.error }, err.status);
        }
        status = 500;
        console.error(`${name} error:`, err);
        logError("unhandled error", {
          function: name,
          error: err instanceof Error ? err.message : String(err),
        });
        Sentry.captureException(err);
        const message = err instanceof Error ? err.message : "An unexpected error occurred";
        return jsonResponse({ error: message }, 500);
      } finally {
        logInfo("request finished", {
          function: name,
          status,
          duration_ms: Date.now() - startedAt,
        });
        // Edge isolates can freeze right after the response; flush in-flight
        // events + logs first (returns fast when the queue is empty).
        await Sentry.flush(2000);
      }
    });
  });
}

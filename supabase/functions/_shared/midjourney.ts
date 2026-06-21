// Midjourney MCP client — TypeScript/Deno port of dream_book's
// midjourney_client.dart + midjourney_auth.dart + midjourney_models.dart.
//
// Protocol: JSON-RPC 2.0 over streamable HTTP (the server replies with SSE).
// Auth: a shared-account access token from MJ_ACCESS_TOKEN; on 401 we refresh
// it using MJ_REFRESH_TOKEN + MJ_CLIENT_ID (OAuth refresh_token grant) and retry
// once. The refreshed access token is cached in a module-level variable.

const ENDPOINT = "https://mcp.midjourney.com/mcp";
const TOKEN_ENDPOINT = "https://mcp.midjourney.com/token";

export class MidjourneyError extends Error {
  code?: number;
  constructor(message: string, code?: number) {
    super(message);
    this.name = "MidjourneyError";
    this.code = code;
  }
}

export interface MidjourneyImage {
  gridIndex: number;
  cdnUrl: string;
  resourceUri: string;
}

export interface MidjourneyJob {
  jobId: string;
  webUrl: string;
  images: MidjourneyImage[];
}

// --- module-level state ----------------------------------------------------

// Mirrors the Dart client's per-instance `_id` / `_initialized`. Module-level
// here because the edge function reuses a single client per worker.
let _rpcId = 0;
let _initialized = false;
// Cached access token; seeded lazily from MJ_ACCESS_TOKEN, replaced on refresh.
let _accessToken: string | null = null;

function currentToken(): string {
  if (_accessToken === null) {
    _accessToken = Deno.env.get("MJ_ACCESS_TOKEN") ?? "";
  }
  return _accessToken;
}

// --- auth: refresh (ports midjourney_auth.dart `_refresh`) -----------------

/**
 * Refresh the access token via the OAuth refresh_token grant, exactly as
 * `MidjourneyAuth._refresh` does: POST x-www-form-urlencoded to the token
 * endpoint with grant_type=refresh_token, the refresh token, and client_id.
 * Caches and returns the new access token.
 */
async function refreshAccessToken(): Promise<string> {
  const refreshToken = Deno.env.get("MJ_REFRESH_TOKEN") ?? "";
  const clientId = Deno.env.get("MJ_CLIENT_ID") ?? "";
  if (!refreshToken || !clientId) {
    throw new MidjourneyError(
      "Cannot refresh Midjourney token: MJ_REFRESH_TOKEN / MJ_CLIENT_ID not set",
      401,
    );
  }

  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: clientId,
  });

  const res = await fetch(TOKEN_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  if (res.status !== 200) {
    const text = await res.text();
    throw new MidjourneyError(
      `Token refresh failed: ${res.status} ${text}`,
      res.status,
    );
  }

  const json = await res.json() as { access_token?: string };
  const accessToken = json.access_token;
  if (!accessToken) {
    throw new MidjourneyError("Token refresh response missing access_token", 401);
  }
  _accessToken = accessToken;
  // A fresh token means the MCP session must re-initialize.
  _initialized = false;
  return accessToken;
}

// --- SSE parsing (ports `_parseSse`) ---------------------------------------

interface RpcMessage {
  id?: number | string;
  result?: Record<string, unknown>;
  error?: { message?: string; code?: number };
}

/**
 * Responses come back as SSE: lines like `data: {<json>}`. Find the JSON-RPC
 * message matching [id] (or fall back to the last decodable one).
 */
function parseSse(body: string, id: number): RpcMessage | null {
  let last: RpcMessage | null = null;
  for (const line of body.split(/\r?\n/)) {
    if (!line.startsWith("data:")) continue;
    const payload = line.slice(5).trim();
    if (payload.length === 0 || payload === "[DONE]") continue;
    try {
      const obj = JSON.parse(payload) as RpcMessage;
      last = obj;
      if (obj.id === id) return obj;
    } catch (_) {
      // ignore non-JSON SSE lines (event:, comments, etc.)
    }
  }
  return last;
}

// --- JSON-RPC plumbing (ports `_rpc`) --------------------------------------

async function rpc(
  token: string,
  method: string,
  params: Record<string, unknown>,
): Promise<{ status: number; message: RpcMessage | null; id: number }> {
  const id = ++_rpcId;
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
      "Accept": "application/json, text/event-stream",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id,
      method,
      params,
    }),
  });

  if (res.status === 401) {
    // Drain body so the connection can be reused, then signal caller to refresh.
    await res.text();
    return { status: 401, message: null, id };
  }
  if (res.status >= 400) {
    const text = await res.text();
    throw new MidjourneyError(`HTTP ${res.status}: ${text}`, res.status);
  }

  const text = await res.text();
  const message = parseSse(text, id);
  return { status: res.status, message, id };
}

/** Run one JSON-RPC call, refreshing the token + retrying once on a 401. */
async function rpcWithRetry(
  method: string,
  params: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  let token = currentToken();
  let { status, message, id } = await rpc(token, method, params);

  if (status === 401) {
    token = await refreshAccessToken();
    ({ status, message, id } = await rpc(token, method, params));
    if (status === 401) {
      throw new MidjourneyError("Unauthorized — token rejected after refresh", 401);
    }
  }

  if (message === null) {
    throw new MidjourneyError(`No JSON-RPC response for id ${id}`);
  }
  if (message.error) {
    throw new MidjourneyError(
      message.error.message ?? "RPC error",
      message.error.code,
    );
  }
  return message.result ?? {};
}

// --- handshake + tool call (ports `_ensureInitialized` / `_callTool`) -------

async function ensureInitialized(): Promise<void> {
  if (_initialized) return;
  await rpcWithRetry("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "dreambook", version: "0.1.0" },
  });
  _initialized = true;
}

function extractText(result: Record<string, unknown>): string | null {
  const content = result.content;
  if (Array.isArray(content)) {
    for (const c of content) {
      if (
        c && typeof c === "object" &&
        (c as Record<string, unknown>).type === "text" &&
        typeof (c as Record<string, unknown>).text === "string"
      ) {
        return (c as Record<string, unknown>).text as string;
      }
    }
  }
  return null;
}

async function callTool(
  name: string,
  args: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  await ensureInitialized();
  const result = await rpcWithRetry("tools/call", { name, arguments: args });

  if (result.isError === true) {
    throw new MidjourneyError(extractText(result) ?? "Tool call failed");
  }
  // Prefer the typed structuredContent; fall back to parsing the text block.
  const structured = result.structuredContent;
  if (structured && typeof structured === "object") {
    return structured as Record<string, unknown>;
  }
  const text = extractText(result);
  if (text !== null) {
    return JSON.parse(text) as Record<string, unknown>;
  }
  throw new MidjourneyError("No structured content in tool result");
}

// --- public API (ports `generateImage` + `MidjourneyJob.fromJson`) ----------

/**
 * Generate an image from a prompt. Inline Midjourney flags are allowed,
 * e.g. `"a misty forest --ar 16:9 --stylize 400"`. Blocks tens of seconds.
 * Returns the job id and the grid image CDN URLs.
 */
export async function generateImage(
  prompt: string,
): Promise<{ jobId: string; images: string[] }> {
  const json = await callTool("generate_image", { prompt });

  const jobId = typeof json.job_id === "string" ? json.job_id : "";
  const rawImages = Array.isArray(json.images) ? json.images : [];
  const images = rawImages
    .map((e) => {
      if (e && typeof e === "object") {
        const url = (e as Record<string, unknown>).cdn_url;
        return typeof url === "string" ? url : null;
      }
      return null;
    })
    .filter((u): u is string => u !== null);

  return { jobId, images };
}

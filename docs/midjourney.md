# Midjourney via the official MCP server

We use Midjourney's **official MCP server** (`https://mcp.midjourney.com/mcp`) directly
as our image-generation backend. There is **no public Midjourney REST API** — the MCP
server is the only official programmatic surface. It speaks MCP (JSON-RPC over
streamable HTTP) and authenticates with **standard OAuth 2.1**.

Everything below was verified live against the server on 2026-06-20 (server version
`Midjourney 3.2.4`). A dragon was generated end-to-end with this exact flow.

---

## TL;DR for the app

1. One-time **dynamic client registration** → get a `client_id` (public client, no secret).
2. **OAuth 2.1 + PKCE** authorize in a browser/webview → user logs into *their* Midjourney
   account → redirect back with a code → exchange for `access_token` + `refresh_token`.
3. POST JSON-RPC to `/mcp` with `Authorization: Bearer <access_token>`.
   `initialize`, then `tools/call` → `generate_image`.
4. Responses are **SSE** (`text/event-stream`) — parse the `data:` line(s).
5. `generate_image` **blocks ~tens of seconds** and returns **4 images**; read
   `structuredContent.images[].cdn_url`.

The Dart implementation lives in `dream_book/lib/midjourney/`.

---

## Auth: OAuth 2.1 endpoints

Discovered via the 401 challenge (`WWW-Authenticate` → RFC 9728 metadata):

| Endpoint     | URL                                      |
| ------------ | ---------------------------------------- |
| Authorize    | `https://mcp.midjourney.com/authorize`   |
| Token        | `https://mcp.midjourney.com/token`       |
| Register     | `https://mcp.midjourney.com/register`    |
| Issuer       | `https://mcp.midjourney.com/`            |

- **Scopes:** `media:create mcp:access`
- **PKCE:** `S256` required
- **Grants:** `authorization_code`, `refresh_token`
- **Public client:** `token_endpoint_auth_method: "none"` (no client secret — correct for mobile)
- **Custom-scheme redirect URIs accepted** (e.g. `dreambook://oauth/callback`) → native app can catch the callback.
- **Access token TTL:** `expires_in = 3600` (1 hour). Use the refresh token beyond that.

### Dynamic client registration (do once)

```bash
curl -sS -X POST https://mcp.midjourney.com/register \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "dream_book",
    "redirect_uris": ["dreambook://oauth/callback"],
    "grant_types": ["authorization_code","refresh_token"],
    "response_types": ["code"],
    "token_endpoint_auth_method": "none",
    "scope": "media:create mcp:access"
  }'
# -> { "client_id": "...", ... }   (no secret)
```

You can register once and hardcode the resulting `client_id`, or register at runtime.

### Authorize → token (PKCE)

```
GET https://mcp.midjourney.com/authorize
  ?response_type=code
  &client_id=<client_id>
  &redirect_uri=dreambook://oauth/callback
  &scope=media:create%20mcp:access
  &state=<random>
  &code_challenge=<base64url(sha256(verifier))>
  &code_challenge_method=S256
```

After the user approves, the redirect carries `?code=...&state=...`. Exchange it:

```bash
curl -sS -X POST https://mcp.midjourney.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode grant_type=authorization_code \
  --data-urlencode code=<code> \
  --data-urlencode redirect_uri=dreambook://oauth/callback \
  --data-urlencode client_id=<client_id> \
  --data-urlencode code_verifier=<verifier>
# -> { access_token, token_type, expires_in, scope, refresh_token }
```

Refresh:

```bash
curl -sS -X POST https://mcp.midjourney.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode grant_type=refresh_token \
  --data-urlencode refresh_token=<refresh_token> \
  --data-urlencode client_id=<client_id>
```

> ⚠️ Cloudflare blocks some non-browser TLS fingerprints (Python `urllib` got 403).
> `curl`, Dart's `package:http`, and real browsers/webviews work fine.

---

## Calling the MCP

All calls: `POST https://mcp.midjourney.com/mcp` with headers:

```
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json, text/event-stream
```

Responses are **SSE**. Each line of interest looks like `data: {<json-rpc>}`. Concatenate
/parse the `data:` payloads. No `Mcp-Session-Id` header is required for these calls.

### 1. initialize

```json
{"jsonrpc":"2.0","id":1,"method":"initialize",
 "params":{"protocolVersion":"2025-06-18","capabilities":{},
           "clientInfo":{"name":"dreambook","version":"0.1.0"}}}
```

### 2. tools/call → generate_image

```json
{"jsonrpc":"2.0","id":2,"method":"tools/call",
 "params":{"name":"generate_image",
           "arguments":{"prompt":"a big dragon, epic fantasy --ar 16:9"}}}
```

**Blocks ~tens of seconds.** Use a long client timeout (we use 180s).

### Result shape (what the app consumes)

`result.structuredContent`:

```json
{
  "job_id": "70f8c37d-...",
  "web_url": "https://www.midjourney.com/jobs/70f8c37d-...",
  "images": [
    {"grid_index":0,"cdn_url":"https://cdn.midjourney.com/<job>/0_0.jpeg",
     "resource_uri":"midjourney://image/<job>/0"},
    {"grid_index":1,"cdn_url":".../0_1.jpeg","resource_uri":"...1"},
    {"grid_index":2,"cdn_url":".../0_2.jpeg","resource_uri":"...2"},
    {"grid_index":3,"cdn_url":".../0_3.jpeg","resource_uri":"...3"}
  ]
}
```

`result.content` also contains an inline base64 **webp** thumbnail of the 2×2 grid
(handy for instant preview) plus a `text` copy of the JSON above. The full-res images
are the four `cdn_url` JPEGs.

---

## Tools available

| Tool                       | Purpose |
| -------------------------- | ------- |
| `generate_image`           | Text prompt → 4 images. Inline flags: `--ar`, `--stylize`, `--sref`, `--p`, `--raw`, `--no`, image refs at start + `--iw`. |
| `generate_variation`       | Vary one grid image (`job_id`, `grid_index`, `strength: subtle\|strong`). |
| `upscale`                  | ~2× a grid image (`subtle\|creative`). |
| `inpaint` / `outpaint` / `pan` | Region repaint / zoom out / extend an edge. |
| `get_account_status`       | Plan, fast-time remaining, `concurrent_fast_jobs`. |
| `list_recent_jobs` / `get_job` | History + lineage. |
| `list_my_profiles` / `list_my_moodboards` / `list_my_personalizations` | Personalization refs for `--p`. |

---

## Account / quota (the logged-in account)

- Plan **mega**, **12** concurrent fast jobs, **60** fast-hours/period.
- **Relax mode available** → unlimited generations that don't burn fast time (slower).
  Worth using for non-time-critical generations during the hackathon.
- All `generate_*` calls share the per-plan concurrency budget. On a concurrency/queue
  error, stop launching, let in-flight jobs finish, then resume — don't retry in a tight loop.

---

## Architecture notes

- **Directly in Flutter (current):** the app does OAuth + calls `/mcp` itself. No backend.
  Generation runs under **one** Midjourney account (whoever logged in). Fine for the demo.
- **Real multi-user (later):** either each user OAuths their *own* Midjourney account
  (each needs a paid sub), or move to a backend holding one account + a job queue. The
  `BROWSER_BASE_API_KEY` in `.env` is the fallback for driving Midjourney headlessly if
  the MCP ever doesn't fit — not needed for the current direct path.
- **ToS:** driving the MCP from our own app (not Claude/Cursor) is outside the blessed
  agentic-client use. Fine for a hackathon; revisit before anything public.

---

## Using it from Claude Code (for manual generation)

Already registered in this repo's `.mcp.json`:

```json
{ "mcpServers": { "midjourney": { "type": "http", "url": "https://mcp.midjourney.com/mcp" } } }
```

Restart Claude Code in this directory, approve the project MCP server, then ask it to
generate an image — a browser window opens once for login, after which the session stays
active. View results at https://www.midjourney.com/imagine.

Resources:
- MCP docs: https://www.midjourney.com/mcp-docs
- Prompting / parameters: https://docs.midjourney.com/
- Explore: https://www.midjourney.com/explore

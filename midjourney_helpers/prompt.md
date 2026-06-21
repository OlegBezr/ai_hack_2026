# Midjourney credential generation (for agents)

`./mj_auth.py` mints a fresh Midjourney OAuth token set (access + refresh + the
`client_id` it registered) via the official MCP server's OAuth 2.1 flow (Dynamic
Client Registration + PKCE). Use it whenever you need working Midjourney creds, or
when the existing refresh token is dead (`invalid_grant: refresh token does not
exist`). The minted set seeds two places:
- **Flutter direct path** → `dream_book/.env` (`MJ_ACCESS_TOKEN`,
  `MJ_REFRESH_TOKEN`, `MJ_CLIENT_ID`).
- **Edge-function path** → the `midjourney_oauth` Supabase Vault secret, which
  requires `access_token`, `refresh_token`, **and** `client_id`.
  See "Seeding the Midjourney key in Vault" in `DEVELOPMENT.md`.

## What it does
1. `POST https://mcp.midjourney.com/register` → public `client_id` (no secret).
2. Generates a PKCE verifier/challenge and builds the `/authorize` URL.
3. Starts a tiny local callback server on `http://localhost:8765/callback`.
4. Waits (up to 5 min) for the user to log in, captures the `code`.
5. `POST /token` → exchanges code for tokens, saves them to JSON.

## How to run it
```bash
rm -f /tmp/mj_token.json /tmp/mj_authurl.txt
nohup python3 midjourney_helpers/mj_auth.py > /tmp/mj_auth.log 2>&1 &
sleep 4
cat /tmp/mj_authurl.txt      # the authorize URL
```
- Requires `python3` and `curl` (curl is used for the HTTP calls — plain urllib gets
  403'd by Cloudflare).
- **Give the user the authorize URL from `/tmp/mj_authurl.txt`** and ask them to open
  it and log into Midjourney. It is the official `mcp.midjourney.com` domain.

## Where the creds get saved → TELL THE USER THIS PATH
**`/tmp/mj_token.json`** — give this path to the user so they know where their tokens are.

Wait for it to appear:
```bash
for i in $(seq 1 40); do
  [ -f /tmp/mj_token.json ] && { echo READY; break; }
  grep -q "AUTH_ERROR\|AUTH_TIMEOUT" /tmp/mj_auth.log 2>/dev/null && { echo FAILED; break; }
  sleep 3
done
```

The file looks like:
```json
{
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "media:create mcp:access",
  "refresh_token": "<token>",
  "client_id": "<uuid>"
}
```
(`client_id` is added by the script — it's the DCR `client_id`, required for both
seed destinations above; the rest come straight from the `/token` response.)

## Progress markers (stdout / `/tmp/mj_auth.log`)
- `AUTHORIZE_URL_READY` — URL written to `/tmp/mj_authurl.txt`.
- `TOKEN_SAVED` — tokens written to `/tmp/mj_token.json`.
- `AUTH_ERROR` / `AUTH_TIMEOUT` — login failed or user didn't finish in 5 min.

## Notes
- Access token: ~1h life. `refresh_token`: single-use, **rotates** on every refresh —
  so any copy you stash (e.g. in `.env`) is a one-time seed, dead after the first
  in-app refresh.
- Don't drive generations from Claude Code's MCP and an app at the same time — same
  account, rotating tokens, they invalidate each other.
- Full protocol details (endpoints, scopes, tool contract): `docs/midjourney.md`.

import json, os, base64, hashlib, secrets, urllib.parse, http.server, threading, time, subprocess

BASE = "https://mcp.midjourney.com"
REDIRECT = "http://localhost:8765/callback"
SCOPE = "media:create mcp:access"
STATE_FILE = "/tmp/mj_token.json"
URL_FILE = "/tmp/mj_authurl.txt"

def post_json(url, data):
    out = subprocess.check_output([
        "curl", "-sS", "-X", "POST", url,
        "-H", "Content-Type: application/json",
        "-d", json.dumps(data), "--max-time", "30",
    ])
    return json.loads(out.decode())

def post_form(url, data):
    args = ["curl", "-sS", "-X", "POST", url, "-H", "Content-Type: application/x-www-form-urlencoded", "--max-time", "30"]
    for k, v in data.items():
        args += ["--data-urlencode", f"{k}={v}"]
    out = subprocess.check_output(args)
    return json.loads(out.decode())

# 1. Register a public client with a localhost redirect
reg = post_json(BASE + "/register", {
    "client_name": "dream_book dev",
    "redirect_uris": [REDIRECT],
    "grant_types": ["authorization_code", "refresh_token"],
    "response_types": ["code"],
    "token_endpoint_auth_method": "none",
    "scope": SCOPE,
})
client_id = reg["client_id"]

# 2. PKCE
verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
state = secrets.token_urlsafe(16)

auth_url = BASE + "/authorize?" + urllib.parse.urlencode({
    "response_type": "code",
    "client_id": client_id,
    "redirect_uri": REDIRECT,
    "scope": SCOPE,
    "state": state,
    "code_challenge": challenge,
    "code_challenge_method": "S256",
})

with open(URL_FILE, "w") as f:
    f.write(auth_url + "\n")
print("AUTHORIZE_URL_READY", flush=True)

# 3. Local callback server
captured = {}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        q = urllib.parse.urlparse(self.path)
        if q.path != "/callback":
            self.send_response(404); self.end_headers(); return
        params = dict(urllib.parse.parse_qsl(q.query))
        captured.update(params)
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(b"<h2>Login complete. You can close this tab and return to Claude Code.</h2>")

srv = http.server.HTTPServer(("localhost", 8765), H)
# serve until we get a code or timeout
deadline = time.time() + 300
while time.time() < deadline and "code" not in captured and "error" not in captured:
    srv.timeout = 1
    srv.handle_request()

if "error" in captured:
    print("AUTH_ERROR", json.dumps(captured), flush=True)
    raise SystemExit(1)
if "code" not in captured:
    print("AUTH_TIMEOUT", flush=True)
    raise SystemExit(1)

# 4. Exchange code for tokens
tok = post_form(BASE + "/token", {
    "grant_type": "authorization_code",
    "code": captured["code"],
    "redirect_uri": REDIRECT,
    "client_id": client_id,
    "code_verifier": verifier,
})
tok["_client_id"] = client_id
with open(STATE_FILE, "w") as f:
    json.dump(tok, f, indent=2)
print("TOKEN_SAVED", flush=True)

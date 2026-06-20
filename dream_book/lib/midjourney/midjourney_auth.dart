import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'midjourney_models.dart';

/// Handles OAuth 2.1 (DCR + PKCE + refresh) against the Midjourney MCP server.
///
/// Auth surface is documented in `docs/midjourney.md`. This is a public client
/// (no client secret) using a custom-scheme redirect.
///
/// NATIVE SETUP REQUIRED for the redirect to come back to the app:
///   * Android: add an intent-filter for scheme `dreambook` to the
///     `com.linusu.flutter_web_auth_2.CallbackActivity` in AndroidManifest.xml.
///   * iOS: add `dreambook` to CFBundleURLSchemes in Info.plist.
/// See flutter_web_auth_2 README for the exact snippets.
class MidjourneyAuth {
  MidjourneyAuth({
    this.clientId,
    http.Client? httpClient,
    FlutterSecureStorage? storage,
  })  : _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Shared-account / demo path: seed an existing token set and skip the
  /// interactive OAuth flow entirely.
  ///
  /// Pass all three. A bare access token expires in ~1h; the [refreshToken] +
  /// [clientId] let the client mint fresh access tokens automatically (the
  /// refresh token rotates and is persisted on each refresh).
  ///
  /// [expiresAt] defaults to "already expired" so the very first call refreshes
  /// immediately — that way a possibly-stale pasted access token is replaced
  /// with a known-good one before any tool call.
  factory MidjourneyAuth.withTokens({
    required String accessToken,
    required String refreshToken,
    required String clientId,
    DateTime? expiresAt,
    http.Client? httpClient,
    FlutterSecureStorage? storage,
  }) {
    final auth = MidjourneyAuth(
      clientId: clientId,
      httpClient: httpClient,
      storage: storage,
    );
    auth._tokens = MidjourneyTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      scope: scope,
    );
    return auth;
  }

  /// Build from a bundled `.env` (loaded via flutter_dotenv). Call
  /// `await dotenv.load(fileName: ".env")` in main() before constructing.
  ///
  /// Expected keys: MJ_ACCESS_TOKEN, MJ_REFRESH_TOKEN, MJ_CLIENT_ID.
  /// Falls back to interactive OAuth if any are missing.
  ///
  /// Note: a `.env`-seeded refresh token is single-use — after the first
  /// in-app refresh the live token lives in secure storage and the `.env`
  /// value is stale. Re-seed only matters on a fresh install / cleared storage.
  factory MidjourneyAuth.fromDotenv({
    http.Client? httpClient,
    FlutterSecureStorage? storage,
  }) {
    final at = dotenv.maybeGet('MJ_ACCESS_TOKEN') ?? '';
    final rt = dotenv.maybeGet('MJ_REFRESH_TOKEN') ?? '';
    final cid = dotenv.maybeGet('MJ_CLIENT_ID') ?? '';
    if (at.isEmpty || rt.isEmpty || cid.isEmpty) {
      return MidjourneyAuth(httpClient: httpClient, storage: storage);
    }
    return MidjourneyAuth.withTokens(
      accessToken: at,
      refreshToken: rt,
      clientId: cid,
      httpClient: httpClient,
      storage: storage,
    );
  }

  /// Build from `--dart-define`s so secrets stay out of source control:
  ///   flutter run \
  ///     --dart-define=MJ_ACCESS_TOKEN=... \
  ///     --dart-define=MJ_REFRESH_TOKEN=... \
  ///     --dart-define=MJ_CLIENT_ID=...
  /// Falls back to interactive OAuth if any are missing.
  factory MidjourneyAuth.fromEnvironment({
    http.Client? httpClient,
    FlutterSecureStorage? storage,
  }) {
    const at = String.fromEnvironment('MJ_ACCESS_TOKEN');
    const rt = String.fromEnvironment('MJ_REFRESH_TOKEN');
    const cid = String.fromEnvironment('MJ_CLIENT_ID');
    if (at.isEmpty || rt.isEmpty || cid.isEmpty) {
      return MidjourneyAuth(httpClient: httpClient, storage: storage);
    }
    return MidjourneyAuth.withTokens(
      accessToken: at,
      refreshToken: rt,
      clientId: cid,
      httpClient: httpClient,
      storage: storage,
    );
  }

  static const _base = 'https://mcp.midjourney.com';
  static const authorizeEndpoint = '$_base/authorize';
  static const tokenEndpoint = '$_base/token';
  static const registerEndpoint = '$_base/register';

  static const callbackScheme = 'dreambook';
  static const redirectUri = '$callbackScheme://oauth/callback';
  static const scope = 'media:create mcp:access';

  static const _tokenKey = 'mj_tokens';
  static const _clientIdKey = 'mj_client_id';

  /// Optional pre-registered client_id. If null, we register dynamically once
  /// and cache the result in secure storage.
  String? clientId;

  final http.Client _http;
  final FlutterSecureStorage _storage;

  MidjourneyTokens? _tokens;

  /// Returns a valid access token, running the full login flow if needed and
  /// refreshing transparently when expired.
  Future<String> getAccessToken() async {
    _tokens ??= await _loadTokens();

    if (_tokens == null) {
      await login();
      return _tokens!.accessToken;
    }
    if (_tokens!.isExpired) {
      await _refresh();
    }
    return _tokens!.accessToken;
  }

  bool get isLoggedIn => _tokens != null;

  /// Full interactive login: ensure a client_id, run PKCE authorize in a
  /// browser tab, exchange the code for tokens, and persist them.
  Future<void> login() async {
    final cid = await _ensureClientId();
    final verifier = _randomUrlSafe(64);
    final challenge = _s256(verifier);
    final state = _randomUrlSafe(16);

    final authUrl = Uri.parse(authorizeEndpoint).replace(queryParameters: {
      'response_type': 'code',
      'client_id': cid,
      'redirect_uri': redirectUri,
      'scope': scope,
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: callbackScheme,
    );

    final params = Uri.parse(result).queryParameters;
    if (params['error'] != null) {
      throw MidjourneyException('Authorization failed: ${params['error']}');
    }
    if (params['state'] != state) {
      throw MidjourneyException('OAuth state mismatch');
    }
    final code = params['code'];
    if (code == null) {
      throw MidjourneyException('No authorization code returned');
    }

    final tokens = await _exchangeCode(cid, code, verifier);
    _tokens = tokens;
    await _saveTokens(tokens);
  }

  /// Forget cached tokens (does not revoke server-side).
  Future<void> logout() async {
    _tokens = null;
    await _storage.delete(key: _tokenKey);
  }

  // --- internals ---------------------------------------------------------

  Future<String> _ensureClientId() async {
    if (clientId != null) return clientId!;
    final cached = await _storage.read(key: _clientIdKey);
    if (cached != null) {
      clientId = cached;
      return cached;
    }
    final cid = await _register();
    clientId = cid;
    await _storage.write(key: _clientIdKey, value: cid);
    return cid;
  }

  Future<String> _register() async {
    final res = await _http.post(
      Uri.parse(registerEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_name': 'dream_book',
        'redirect_uris': [redirectUri],
        'grant_types': ['authorization_code', 'refresh_token'],
        'response_types': ['code'],
        'token_endpoint_auth_method': 'none',
        'scope': scope,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw MidjourneyException(
          'Client registration failed: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['client_id'] as String;
  }

  Future<MidjourneyTokens> _exchangeCode(
      String cid, String code, String verifier) async {
    final res = await _http.post(
      Uri.parse(tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': cid,
        'code_verifier': verifier,
      },
    );
    if (res.statusCode != 200) {
      throw MidjourneyException(
          'Token exchange failed: ${res.statusCode} ${res.body}');
    }
    return MidjourneyTokens.fromTokenResponse(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> _refresh() async {
    final refreshToken = _tokens?.refreshToken;
    final cid = await _ensureClientId();
    if (refreshToken == null) {
      // No refresh token — fall back to interactive login.
      await login();
      return;
    }
    final res = await _http.post(
      Uri.parse(tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': cid,
      },
    );
    if (res.statusCode != 200) {
      // Refresh rejected — re-auth interactively.
      await login();
      return;
    }
    final tokens = MidjourneyTokens.fromTokenResponse(
        jsonDecode(res.body) as Map<String, dynamic>);
    _tokens = tokens;
    await _saveTokens(tokens);
  }

  Future<MidjourneyTokens?> _loadTokens() async {
    final raw = await _storage.read(key: _tokenKey);
    if (raw == null) return null;
    try {
      return MidjourneyTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTokens(MidjourneyTokens tokens) =>
      _storage.write(key: _tokenKey, value: jsonEncode(tokens.toJson()));

  // PKCE helpers
  static String _randomUrlSafe(int bytes) {
    final rng = Random.secure();
    final data = List<int>.generate(bytes, (_) => rng.nextInt(256));
    return base64Url.encode(data).replaceAll('=', '');
  }

  static String _s256(String verifier) =>
      base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'midjourney_auth.dart';
import 'midjourney_models.dart';

/// Thin MCP (JSON-RPC over streamable HTTP) client for the Midjourney server.
///
/// Handles auth, the one-time `initialize` handshake, SSE response parsing, and
/// the `generate_image` / `generate_variation` / `upscale` tool calls.
/// See `docs/midjourney.md` for the verified protocol details.
class MidjourneyClient {
  MidjourneyClient({required this.auth, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _endpoint = 'https://mcp.midjourney.com/mcp';

  final MidjourneyAuth auth;
  final http.Client _http;

  int _id = 0;
  bool _initialized = false;

  /// Generate an image from a prompt. Inline Midjourney flags are allowed,
  /// e.g. `"a misty forest --ar 16:9 --stylize 400"`.
  ///
  /// Blocks ~tens of seconds (one Midjourney job). Returns 4 images.
  Future<MidjourneyJob> generateImage(String prompt) async {
    final result = await _callTool('generate_image', {'prompt': prompt});
    return MidjourneyJob.fromJson(result);
  }

  /// Vary one image from a previous job's grid.
  Future<MidjourneyJob> generateVariation(
    String jobId,
    int gridIndex, {
    String strength = 'subtle', // 'subtle' | 'strong'
  }) async {
    final result = await _callTool('generate_variation', {
      'job_id': jobId,
      'grid_index': gridIndex,
      'strength': strength,
    });
    return MidjourneyJob.fromJson(result);
  }

  /// Upscale (~2x) one image from a previous job's grid.
  Future<MidjourneyJob> upscale(
    String jobId,
    int gridIndex, {
    String strength = 'subtle', // 'subtle' | 'creative'
  }) async {
    final result = await _callTool('upscale', {
      'job_id': jobId,
      'grid_index': gridIndex,
      'strength': strength,
    });
    return MidjourneyJob.fromJson(result);
  }

  /// Subscription/quota status (plan, fast time, concurrency).
  Future<Map<String, dynamic>> getAccountStatus() =>
      _callTool('get_account_status', {});

  // --- internals ---------------------------------------------------------

  Future<void> _ensureInitialized(String token) async {
    if (_initialized) return;
    await _rpc(token, 'initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': {},
      'clientInfo': {'name': 'dreambook', 'version': '0.1.0'},
    });
    _initialized = true;
  }

  Future<Map<String, dynamic>> _callTool(
      String name, Map<String, dynamic> arguments) async {
    final token = await auth.getAccessToken();
    await _ensureInitialized(token);
    final result =
        await _rpc(token, 'tools/call', {'name': name, 'arguments': arguments});

    if (result['isError'] == true) {
      throw MidjourneyException(_extractText(result) ?? 'Tool call failed');
    }
    // Prefer the typed structuredContent; fall back to parsing the text block.
    final structured = result['structuredContent'];
    if (structured is Map<String, dynamic>) return structured;

    final text = _extractText(result);
    if (text != null) {
      return jsonDecode(text) as Map<String, dynamic>;
    }
    throw MidjourneyException('No structured content in tool result');
  }

  /// Performs one JSON-RPC call and returns the `result` object.
  Future<Map<String, dynamic>> _rpc(
      String token, String method, Map<String, dynamic> params) async {
    final id = ++_id;
    final res = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );

    if (res.statusCode == 401) {
      throw MidjourneyException('Unauthorized — token rejected', code: 401);
    }
    if (res.statusCode >= 400) {
      throw MidjourneyException('HTTP ${res.statusCode}: ${res.body}',
          code: res.statusCode);
    }

    final message = _parseSse(res.body, id);
    if (message == null) {
      throw MidjourneyException('No JSON-RPC response for id $id');
    }
    if (message['error'] != null) {
      final err = message['error'] as Map<String, dynamic>;
      throw MidjourneyException(err['message']?.toString() ?? 'RPC error',
          code: (err['code'] as num?)?.toInt());
    }
    return (message['result'] as Map<String, dynamic>?) ?? {};
  }

  /// Responses come back as SSE: lines like `data: {<json>}`. Find the
  /// JSON-RPC message matching [id] (or the last decodable one).
  Map<String, dynamic>? _parseSse(String body, int id) {
    Map<String, dynamic>? last;
    for (final line in const LineSplitter().convert(body)) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final obj = jsonDecode(payload) as Map<String, dynamic>;
        last = obj;
        if (obj['id'] == id) return obj;
      } catch (_) {
        // ignore non-JSON SSE lines (event:, comments, etc.)
      }
    }
    return last;
  }

  String? _extractText(Map<String, dynamic> result) {
    final content = result['content'];
    if (content is List) {
      for (final c in content) {
        if (c is Map && c['type'] == 'text' && c['text'] is String) {
          return c['text'] as String;
        }
      }
    }
    return null;
  }
}

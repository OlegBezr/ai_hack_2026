import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thrown when a Deepgram REST call fails or the key is missing.
class DeepgramException implements Exception {
  DeepgramException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() =>
      'DeepgramException${code != null ? ' ($code)' : ''}: $message';
}

/// Thin REST client for Deepgram's speech-to-text and text-to-speech APIs.
///
/// Both methods are plain one-shot HTTPS round-trips — no WebSocket, no
/// streaming. This is the simplest correct integration: record a clip, POST it
/// to `/v1/listen` for a transcript; POST text to `/v1/speak` for spoken audio.
/// Swap [transcribe] for a streaming WebSocket later if you want live captions;
/// nothing else has to change.
///
/// The API key is read once from the bundled `.env` (`DEEPGRAM_API_KEY`).
/// See `docs/deepgram.md` for the verified request/response shapes.
class DeepgramService {
  DeepgramService({String? apiKey, http.Client? httpClient})
      : _apiKey = apiKey ??
            dotenv.maybeGet('DEEPGRAM_KEY') ??
            dotenv.maybeGet('DEEPGRAM_API_KEY'),
        _http = httpClient ?? http.Client();

  static const _listenEndpoint = 'https://api.deepgram.com/v1/listen';
  static const _speakEndpoint = 'https://api.deepgram.com/v1/speak';

  /// Default STT model. nova-3 is Deepgram's latest general model and
  /// `smart_format` adds punctuation/capitalisation suitable for a prompt.
  static const _sttModel = 'nova-3';

  /// Default TTS voice (Deepgram Aura 2). Returns MP3 audio.
  static const _ttsModel = 'aura-2-thalia-en';

  final String? _apiKey;
  final http.Client _http;

  /// Whether a key was found at construction time. The demo uses this to show
  /// a friendly "add your key" message instead of failing on first tap.
  bool get hasKey => _apiKey != null && _apiKey.isNotEmpty;

  String get _key {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw DeepgramException(
        'DEEPGRAM_KEY is not set. Add it to dream_book/.env and restart.',
      );
    }
    return key;
  }

  /// Transcribe a recorded audio clip.
  ///
  /// [audioBytes] is the raw file content; [contentType] must match how it was
  /// recorded (the demo records WAV/linear16, so `audio/wav`). Deepgram also
  /// sniffs most containers, but an honest content-type avoids surprises.
  /// Returns the best-alternative transcript (possibly empty for silence).
  Future<String> transcribe(
    Uint8List audioBytes, {
    String contentType = 'audio/wav',
    String model = _sttModel,
  }) async {
    final uri = Uri.parse(_listenEndpoint).replace(queryParameters: {
      'model': model,
      'smart_format': 'true',
    });

    final res = await _http.post(
      uri,
      headers: {
        'Authorization': 'Token $_key',
        'Content-Type': contentType,
      },
      body: audioBytes,
    );

    if (res.statusCode >= 400) {
      throw DeepgramException(
        'listen failed: ${res.body}',
        code: res.statusCode,
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    try {
      final alt = (((json['results'] as Map)['channels'] as List).first
          as Map)['alternatives'] as List;
      return ((alt.first as Map)['transcript'] as String?)?.trim() ?? '';
    } catch (_) {
      throw DeepgramException('Unexpected listen response: ${res.body}');
    }
  }

  /// Synthesize [text] to spoken audio and return the raw MP3 bytes.
  ///
  /// Feed the result to an audio player (the demo writes it to a temp file and
  /// plays it with just_audio). Call the player's `stop()` to barge in.
  Future<Uint8List> speak(
    String text, {
    String model = _ttsModel,
  }) async {
    final uri = Uri.parse(_speakEndpoint).replace(queryParameters: {
      'model': model,
    });

    final res = await _http.post(
      uri,
      headers: {
        'Authorization': 'Token $_key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );

    if (res.statusCode >= 400) {
      throw DeepgramException(
        'speak failed: ${res.body}',
        code: res.statusCode,
      );
    }
    return res.bodyBytes;
  }
}

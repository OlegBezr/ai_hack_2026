import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'voice_audio.dart';

/// High-level phase of the live conversation, surfaced to the UI.
enum VoiceAgentPhase { idle, connecting, listening, thinking, speaking, error }

/// One line of the running conversation transcript.
class VoiceTurn {
  VoiceTurn({required this.role, required this.text});

  /// `'user'` or `'assistant'`.
  final String role;
  final String text;

  bool get isUser => role == 'user';
}

/// Drives a full **voice-to-voice** conversation against Deepgram's Voice Agent
/// API over a single WebSocket (`wss://agent.deepgram.com/v1/agent/converse`).
///
/// The agent runs the whole pipeline server-side: it transcribes the mic audio
/// we stream up (STT), feeds the transcript to a **Deepgram-managed LLM** primed
/// with the book as its system prompt (no separate OpenAI/Anthropic key needed),
/// and streams synthesized speech back down (TTS) — which we play immediately.
///
/// This is a [ChangeNotifier] so the chat sheet can rebuild on [phase] and
/// [transcript] changes. Audio plumbing lives in [VoiceAudioEngine]; this class
/// only speaks the JSON/binary WebSocket protocol.
class VoiceAgentController extends ChangeNotifier {
  VoiceAgentController({String? apiKey})
    : _apiKey =
          apiKey ??
          dotenv.maybeGet('DEEPGRAM_KEY') ??
          dotenv.maybeGet('DEEPGRAM_API_KEY');

  static final Uri _endpoint = Uri.parse(
    'wss://agent.deepgram.com/v1/agent/converse',
  );

  final String? _apiKey;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  VoiceAudioEngine? _audio;

  VoiceAgentPhase _phase = VoiceAgentPhase.idle;
  VoiceAgentPhase get phase => _phase;

  String? _error;
  String? get error => _error;

  final List<VoiceTurn> _transcript = [];
  List<VoiceTurn> get transcript => List.unmodifiable(_transcript);

  bool get hasKey => _apiKey != null && _apiKey.isNotEmpty;

  /// Open the socket, configure the agent with [systemPrompt] (the book) and an
  /// optional spoken [greeting], then start streaming the mic.
  Future<void> connect({
    required String systemPrompt,
    String? greeting,
  }) async {
    if (!hasKey) {
      _fail('DEEPGRAM_KEY is not set. Add it to dream_book/.env and restart.');
      return;
    }
    _setPhase(VoiceAgentPhase.connecting);

    try {
      // Browsers can't set an Authorization header on a WebSocket, so Deepgram
      // accepts the key as a `token` subprotocol: `Sec-WebSocket-Protocol:
      // token, <key>`.
      _channel = WebSocketChannel.connect(
        _endpoint,
        protocols: ['token', _apiKey!],
      );
      await _channel!.ready;

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (Object e) => _fail('Connection error: $e'),
        onDone: _onDone,
      );

      _send(_settings(systemPrompt: systemPrompt, greeting: greeting));

      _audio = VoiceAudioEngine();
      await _audio!.startCapture(_onMicChunk);
      _setPhase(VoiceAgentPhase.listening);
    } catch (e) {
      _fail('Failed to start voice chat: $e');
    }
  }

  /// Stop the mic, close the socket, and reset to idle.
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _audio?.stop();
    _audio = null;
    await _channel?.sink.close();
    _channel = null;
    if (_phase != VoiceAgentPhase.error) _setPhase(VoiceAgentPhase.idle);
  }

  @override
  void dispose() {
    // Fire-and-forget teardown; the notifier is going away regardless.
    disconnect();
    super.dispose();
  }

  // --- WebSocket plumbing ---------------------------------------------------

  void _onMicChunk(Uint8List pcm16le) {
    // Binary frames on this socket are mic audio going up.
    _channel?.sink.add(pcm16le);
  }

  void _onMessage(dynamic message) {
    if (message is String) {
      _onControlMessage(message);
    } else if (message is List<int>) {
      // Binary frames coming down are synthesized speech (linear16 @ 24 kHz).
      _audio?.play(Uint8List.fromList(message));
    }
  }

  /// Handle a JSON control event. See Deepgram's Voice Agent message reference.
  void _onControlMessage(String raw) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (json['type']) {
      case 'UserStartedSpeaking':
        // Barge-in: drop any agent speech still queued and listen.
        _audio?.clearPlayback();
        _setPhase(VoiceAgentPhase.listening);
        break;
      case 'AgentThinking':
        _setPhase(VoiceAgentPhase.thinking);
        break;
      case 'AgentStartedSpeaking':
        _setPhase(VoiceAgentPhase.speaking);
        break;
      case 'AgentAudioDone':
        _setPhase(VoiceAgentPhase.listening);
        break;
      case 'ConversationText':
        _appendTurn(
          role: json['role'] as String? ?? 'assistant',
          text: (json['content'] as String? ?? '').trim(),
        );
        break;
      case 'Error':
        _fail(
          'Agent error: ${json['description'] ?? json['message'] ?? raw}',
        );
        break;
    }
  }

  void _onDone() {
    if (_phase != VoiceAgentPhase.error && _phase != VoiceAgentPhase.idle) {
      _setPhase(VoiceAgentPhase.idle);
    }
  }

  // --- helpers --------------------------------------------------------------

  void _appendTurn({required String role, required String text}) {
    if (text.isEmpty) return;
    final last = _transcript.isNotEmpty ? _transcript.last : null;
    // Deepgram emits one ConversationText per finalized turn, but coalesce
    // consecutive same-role lines just in case.
    if (last != null && last.role == role) {
      _transcript[_transcript.length - 1] = VoiceTurn(
        role: role,
        text: '${last.text} $text'.trim(),
      );
    } else {
      _transcript.add(VoiceTurn(role: role, text: text));
    }
    notifyListeners();
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Map<String, dynamic> _settings({
    required String systemPrompt,
    String? greeting,
  }) {
    return {
      'type': 'Settings',
      'audio': {
        'input': {'encoding': 'linear16', 'sample_rate': 16000},
        // `container: none` => raw PCM frames we can hand straight to Web Audio.
        'output': {
          'encoding': 'linear16',
          'sample_rate': 24000,
          'container': 'none',
        },
      },
      'agent': {
        'language': 'en',
        'listen': {
          'provider': {'type': 'deepgram', 'model': 'nova-3'},
        },
        // Omitting `endpoint` uses Deepgram's managed LLM — no extra key.
        'think': {
          'provider': {'type': 'open_ai', 'model': 'gpt-4o-mini'},
          'prompt': systemPrompt,
        },
        'speak': {
          'provider': {'type': 'deepgram', 'model': 'aura-2-thalia-en'},
        },
        if (greeting != null && greeting.isNotEmpty) 'greeting': greeting,
      },
    };
  }

  void _setPhase(VoiceAgentPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    if (phase != VoiceAgentPhase.error) _error = null;
    notifyListeners();
  }

  void _fail(String message) {
    _error = message;
    _phase = VoiceAgentPhase.error;
    notifyListeners();
  }
}

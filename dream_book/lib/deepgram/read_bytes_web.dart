import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

/// Web: Opus via the browser's native MediaRecorder starts instantly. WAV on
/// web goes through `record`'s AudioWorklet encoder, which blocks the UI thread
/// while it spins up (and hangs outright if its worklet asset isn't served) —
/// that's the "stuck on Starting…" freeze. Deepgram decodes WebM/Opus fine.
RecordConfig recordingConfig() =>
    const RecordConfig(encoder: AudioEncoder.opus, numChannels: 1);

/// Content-type matching [recordingConfig]'s output, for the Deepgram request.
/// `record` wraps Opus in a WebM container on web.
String recordingContentType() => 'audio/webm';

/// Web: `record` returns a blob URL, which is fetchable over http.
Future<Uint8List> readRecordingBytes(String path) async =>
    (await http.get(Uri.parse(path))).bodyBytes;

/// Web: `record` ignores the path and hands back a blob URL on stop, so this is
/// only a filename hint — any non-empty value works. No temp filesystem, no
/// `path_provider` (which has no web implementation).
Future<String> recordingTargetPath() async => 'deepgram_clip.wav';

/// Web: there's no temp filesystem for just_audio to read, so hand it the MP3
/// as a base64 data URL instead of staging a file.
Future<void> playAudioBytes(AudioPlayer player, Uint8List bytes) async {
  final url = 'data:audio/mpeg;base64,${base64Encode(bytes)}';
  await player.setUrl(url);
}

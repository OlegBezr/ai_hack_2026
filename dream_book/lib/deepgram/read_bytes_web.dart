import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

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

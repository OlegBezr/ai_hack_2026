import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Web: `record` returns a blob URL, which is fetchable over http.
Future<Uint8List> readRecordingBytes(String path) async =>
    (await http.get(Uri.parse(path))).bodyBytes;

/// Web has no temp filesystem for just_audio to read; TTS playback here is a
/// native-first feature. Wire a blob/data URL source if you need it on web.
Future<void> writeRecordingBytes(String path, Uint8List bytes) async =>
    throw UnsupportedError('TTS file staging is not supported on web.');

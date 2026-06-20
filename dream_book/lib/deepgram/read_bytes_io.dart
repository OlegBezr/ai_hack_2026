import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Native: WAV/linear16 records cleanly and gives Deepgram an honest
/// content-type. The native encoders don't need any browser AudioWorklet.
RecordConfig recordingConfig() => const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    );

/// Content-type matching [recordingConfig]'s output, for the Deepgram request.
String recordingContentType() => 'audio/wav';

/// Native: `record` returns a real filesystem path.
Future<Uint8List> readRecordingBytes(String path) => File(path).readAsBytes();

/// Native: a real temp path for `record` to write the recorded clip to.
Future<String> recordingTargetPath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/deepgram_clip.wav';
}

/// Native: stage the TTS MP3 in a temp file and point the player at it.
Future<void> playAudioBytes(AudioPlayer player, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = '${dir.path}/deepgram_tts.mp3';
  await File(file).writeAsBytes(bytes, flush: true);
  await player.setFilePath(file);
}

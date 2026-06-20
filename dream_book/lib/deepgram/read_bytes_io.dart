import 'dart:io';
import 'dart:typed_data';

/// Native: `record` returns a real filesystem path.
Future<Uint8List> readRecordingBytes(String path) => File(path).readAsBytes();

/// Native: stage TTS audio in a temp file for the player to read.
Future<void> writeRecordingBytes(String path, Uint8List bytes) =>
    File(path).writeAsBytes(bytes, flush: true);

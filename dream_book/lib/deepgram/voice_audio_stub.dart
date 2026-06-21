import 'dart:typed_data';

/// Native placeholder for the Web Audio engine in `voice_audio_web.dart`.
///
/// The live Voice Agent loop is web-first (see `voice_audio.dart`). A native
/// implementation would stream PCM from `record`'s `startStream` into [onChunk]
/// and feed [play] bytes to a raw-PCM player (e.g. a `SoundStreamResume`-style
/// sink). Until that exists, constructing the engine off the web throws so the
/// failure is loud rather than silent.
class VoiceAudioEngine {
  VoiceAudioEngine() {
    throw UnsupportedError(
      'Voice Agent audio is only implemented on web for now. '
      'Run the app in a browser to use the book voice chat.',
    );
  }

  Future<void> startCapture(void Function(Uint8List pcm16le) onChunk) async {}

  void play(Uint8List pcm16le) {}

  void clearPlayback() {}

  Future<void> stop() async {}
}

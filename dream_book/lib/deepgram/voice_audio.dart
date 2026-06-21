/// Real-time microphone capture + raw-PCM playback for the Deepgram Voice
/// Agent loop.
///
/// The Voice Agent streams **raw linear16 PCM** in both directions — mic audio
/// up, synthesized speech down — so we can't reuse the `record`/`just_audio`
/// file round-trip from the one-shot demo. Instead we go straight to Web Audio
/// on web (an [AudioContext] for capture at 16 kHz and another for 24 kHz
/// playback). Native isn't wired yet, so the stub throws.
///
/// The conditional export mirrors `read_bytes.dart`: keep `package:web` out of
/// the native build, where it has no implementation.
library;

export 'voice_audio_stub.dart'
    if (dart.library.html) 'voice_audio_web.dart';

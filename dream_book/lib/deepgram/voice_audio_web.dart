import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web Audio engine for the Deepgram Voice Agent loop.
///
/// Two jobs, two [web.AudioContext]s:
///
///  * **Capture** — open the mic, run it through a [web.ScriptProcessorNode],
///    downmix to mono linear16 at 16 kHz, and hand each chunk to the WebSocket
///    via [startCapture]'s callback. The context is created at the agent's
///    `audio.input.sample_rate` so the browser resamples for us.
///  * **Playback** — the agent streams back raw linear16 at 24 kHz; [play]
///    decodes each chunk into an [web.AudioBuffer] and schedules it on a moving
///    cursor so consecutive chunks butt up seamlessly. [clearPlayback] stops
///    everything in flight, which is how barge-in (cutting the agent off when
///    the user speaks) is implemented.
///
/// `ScriptProcessorNode` is deprecated in favour of `AudioWorklet`, but the
/// worklet path needs a separately-served JS module; the processor keeps this
/// self-contained, which is the right trade for a prototype.
class VoiceAudioEngine {
  // 16 kHz mono in, 24 kHz mono out — matches the Settings message the
  // VoiceAgentController sends.
  static const int _inputSampleRate = 16000;
  static const int _outputSampleRate = 24000;

  web.AudioContext? _inCtx;
  web.AudioContext? _outCtx;
  web.MediaStream? _stream;
  web.MediaStreamAudioSourceNode? _source;
  web.ScriptProcessorNode? _processor;

  /// Playback cursor (in the output context's clock) where the next chunk
  /// should start, so queued chunks play gaplessly.
  double _nextStart = 0;

  /// Sources currently scheduled/playing, so [clearPlayback] can stop them.
  final Set<web.AudioBufferSourceNode> _active = {};

  bool _stopped = false;

  /// Open the mic and begin emitting 16 kHz mono PCM16 (little-endian) chunks.
  ///
  /// Must be called from a user gesture (the chat opens on a button tap), so
  /// `getUserMedia` and the suspended-by-autoplay-policy context both unlock.
  Future<void> startCapture(void Function(Uint8List pcm16le) onChunk) async {
    final inCtx = web.AudioContext(
      web.AudioContextOptions(sampleRate: _inputSampleRate.toDouble()),
    );
    _inCtx = inCtx;
    await inCtx.resume().toDart;

    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    _stream = stream;
    if (_stopped) {
      // Disposed mid-permission-prompt — release the mic we just acquired.
      _stopTracks();
      return;
    }

    final source = inCtx.createMediaStreamSource(stream);
    final processor = inCtx.createScriptProcessor(4096, 1, 1);
    _source = source;
    _processor = processor;

    processor.onaudioprocess =
        (web.AudioProcessingEvent event) {
          final input = event.inputBuffer.getChannelData(0).toDart;
          onChunk(_float32ToPcm16(input));
        }.toJS;

    // ScriptProcessorNode only fires while connected to the graph; the empty
    // output buffer means it contributes silence to the destination.
    source.connect(processor);
    processor.connect(inCtx.destination);
  }

  /// Queue a raw linear16 (24 kHz, mono, little-endian) chunk for playback.
  void play(Uint8List pcm16le) {
    if (_stopped || pcm16le.lengthInBytes < 2) return;
    final outCtx = _outCtx ??= web.AudioContext(
      web.AudioContextOptions(sampleRate: _outputSampleRate.toDouble()),
    );

    final samples = _pcm16ToFloat32(pcm16le);
    final buffer = outCtx.createBuffer(1, samples.length, _outputSampleRate);
    buffer.copyToChannel(samples.toJS, 0);

    final source = outCtx.createBufferSource();
    source.buffer = buffer;
    source.connect(outCtx.destination);

    final now = outCtx.currentTime.toDouble();
    final startAt = _nextStart < now ? now : _nextStart;
    _nextStart = startAt + buffer.duration.toDouble();

    _active.add(source);
    source.onended = (web.Event _) {
      _active.remove(source);
    }.toJS;
    source.start(startAt);
  }

  /// Stop and discard any audio queued for playback (barge-in).
  void clearPlayback() {
    for (final source in _active) {
      try {
        source.stop();
      } catch (_) {
        // Already stopped/ended — fine.
      }
    }
    _active.clear();
    _nextStart = 0;
  }

  /// Tear everything down: stop the mic, drop both contexts, free the graph.
  Future<void> stop() async {
    _stopped = true;
    clearPlayback();
    _stopTracks();
    try {
      _processor?.disconnect();
      _source?.disconnect();
    } catch (_) {}
    _processor = null;
    _source = null;
    await _inCtx?.close().toDart;
    await _outCtx?.close().toDart;
    _inCtx = null;
    _outCtx = null;
  }

  void _stopTracks() {
    final tracks = _stream?.getTracks().toDart;
    if (tracks != null) {
      for (final track in tracks) {
        track.stop();
      }
    }
    _stream = null;
  }

  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final count = bytes.lengthInBytes ~/ 2;
    final view = ByteData.sublistView(bytes);
    final out = Float32List(count);
    for (var i = 0; i < count; i++) {
      out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  static Uint8List _float32ToPcm16(Float32List input) {
    final out = ByteData(input.length * 2);
    for (var i = 0; i < input.length; i++) {
      var sample = input[i];
      if (sample < -1.0) {
        sample = -1.0;
      } else if (sample > 1.0) {
        sample = 1.0;
      }
      out.setInt16(i * 2, (sample * 32767).round(), Endian.little);
    }
    return out.buffer.asUint8List();
  }
}

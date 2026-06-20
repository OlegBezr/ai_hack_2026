import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../deepgram/deepgram_service.dart';
import '../deepgram/read_bytes.dart';

/// Which half of the demo is showing.
enum _Tab { speechToText, textToSpeech }

/// Demo screen for Deepgram, exercising both directions over plain REST:
///
///  * **Speech-to-Text** — record a clip with the mic, POST it to `/v1/listen`,
///    show the transcript.
///  * **Text-to-Speech** — POST text to `/v1/speak`, play the returned MP3.
///
/// No streaming/WebSocket here — a button-driven round-trip is enough to prove
/// the wiring. Swap the STT half for a WebSocket later for live captions.
class DeepgramDemoScreen extends StatefulWidget {
  const DeepgramDemoScreen({super.key});

  @override
  State<DeepgramDemoScreen> createState() => _DeepgramDemoScreenState();
}

class _DeepgramDemoScreenState extends State<DeepgramDemoScreen> {
  final _deepgram = DeepgramService();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  _Tab _tab = _Tab.speechToText;

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deepgram Demo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_deepgram.hasKey) _buildMissingKeyBanner(context),
              SegmentedButton<_Tab>(
                segments: const [
                  ButtonSegment(
                    value: _Tab.speechToText,
                    icon: Icon(Icons.mic),
                    label: Text('Speech → Text'),
                  ),
                  ButtonSegment(
                    value: _Tab.textToSpeech,
                    icon: Icon(Icons.volume_up),
                    label: Text('Text → Speech'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _tab == _Tab.speechToText
                    ? _SpeechToTextPanel(
                        recorder: _recorder,
                        deepgram: _deepgram,
                      )
                    : _TextToSpeechPanel(
                        deepgram: _deepgram,
                        player: _player,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingKeyBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.key_off, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'DEEPGRAM_KEY missing. Add it to dream_book/.env and '
              'restart the app.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Speech → Text ---------------------------------------------------------

class _SpeechToTextPanel extends StatefulWidget {
  const _SpeechToTextPanel({required this.recorder, required this.deepgram});

  final AudioRecorder recorder;
  final DeepgramService deepgram;

  @override
  State<_SpeechToTextPanel> createState() => _SpeechToTextPanelState();
}

class _SpeechToTextPanelState extends State<_SpeechToTextPanel> {
  bool _recording = false;
  bool _transcribing = false;
  String? _error;
  String? _transcript;

  /// Toggle recording. Stopping kicks off the Deepgram transcription.
  Future<void> _toggle() async {
    if (_transcribing) return;
    if (_recording) {
      await _stopAndTranscribe();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _transcript = null;
    });
    try {
      if (!await widget.recorder.hasPermission()) {
        setState(() => _error = 'Microphone permission denied.');
        return;
      }
      // WAV/linear16 so the content-type we send Deepgram is honest. The
      // target path is platform-specific (a real temp file on native, an
      // ignored hint on web — `record` hands back a blob URL there).
      final path = await recordingTargetPath();
      await widget.recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      setState(() => _recording = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _stopAndTranscribe() async {
    setState(() => _recording = false);
    String? path;
    try {
      path = await widget.recorder.stop();
    } catch (e) {
      setState(() => _error = e.toString());
      return;
    }
    if (path == null) {
      setState(() => _error = 'Recording produced no audio.');
      return;
    }

    setState(() => _transcribing = true);
    try {
      final Uint8List bytes = await readRecordingBytes(path);
      final transcript = await widget.deepgram.transcribe(bytes);
      if (!mounted) return;
      setState(() {
        _transcript = transcript.isEmpty ? '(no speech detected)' : transcript;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _transcribing ? null : _toggle,
          icon: Icon(_recording ? Icons.stop : Icons.mic),
          label: Text(
            _recording
                ? 'Stop & transcribe'
                : (_transcribing ? 'Transcribing…' : 'Hold a thought — record'),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: _recording ? theme.colorScheme.error : null,
            foregroundColor: _recording ? theme.colorScheme.onError : null,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return _CenteredHint(
        icon: Icons.error_outline,
        color: theme.colorScheme.error,
        title: 'Something went wrong',
        detail: _error,
      );
    }
    if (_transcribing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recording) {
      return _CenteredHint(
        icon: Icons.graphic_eq,
        color: theme.colorScheme.primary,
        title: 'Listening…',
        detail: 'Speak, then tap stop.',
      );
    }
    if (_transcript != null) {
      return Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          child: SelectableText(
            _transcript!,
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
    }
    return _CenteredHint(
      icon: Icons.mic_none,
      color: theme.colorScheme.outline,
      title: 'Tap record and describe your dream.',
    );
  }
}

// --- Text → Speech ---------------------------------------------------------

class _TextToSpeechPanel extends StatefulWidget {
  const _TextToSpeechPanel({required this.deepgram, required this.player});

  final DeepgramService deepgram;
  final AudioPlayer player;

  @override
  State<_TextToSpeechPanel> createState() => _TextToSpeechPanelState();
}

class _TextToSpeechPanelState extends State<_TextToSpeechPanel> {
  final _controller = TextEditingController(
    text: 'In the dream, the city folded itself into a paper bird and flew.',
  );

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Synthesize the current text and play it. Any in-flight audio is stopped
  /// first so a new tap barges in cleanly.
  Future<void> _speak() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.player.stop();
      final bytes = await widget.deepgram.speak(text);

      // just_audio plays from a file/URL, not raw bytes. Staging is
      // platform-specific: a temp file on native, a base64 data URL on web.
      await playAudioBytes(widget.player, bytes);
      await widget.player.play();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() => widget.player.stop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Text to speak',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _speak,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up),
                label: Text(_busy ? 'Synthesizing…' : 'Speak'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Reflect the player's lifecycle so the user sees playback progress.
        StreamBuilder<PlayerState>(
          stream: widget.player.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final processing = state?.processingState;
            final label = _busy
                ? 'Calling Deepgram…'
                : playing
                    ? 'Playing…'
                    : processing == ProcessingState.completed
                        ? 'Done.'
                        : 'Idle.';
            return Text(label, style: theme.textTheme.bodyMedium);
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}

// --- shared ----------------------------------------------------------------

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}

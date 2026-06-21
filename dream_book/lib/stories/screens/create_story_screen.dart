import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../deepgram/deepgram_service.dart';
import '../../deepgram/read_bytes.dart';
import '../../theme/app_theme.dart';
import '../../theme/magical_widgets.dart';
import '../data/models.dart';
import '../data/stories_repository.dart';

/// "Tell a story" — speak (or type) a whole story, let Claude split it into
/// pages, then generate every page's narration + illustration (and the cover)
/// in parallel before opening the finished book.
///
/// Flow:  record/type → compose (Anthropic) → fan-out media → read.
class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

enum _Phase { input, composing, generating }

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _deepgram = DeepgramService();
  final _recorder = AudioRecorder();
  final _transcript = TextEditingController();
  final _title = TextEditingController();

  _Phase _phase = _Phase.input;
  bool _starting = false;
  bool _recording = false;
  bool _transcribing = false;
  String? _error;

  // Generation progress.
  String _statusLine = '';
  int _mediaDone = 0;
  int _mediaTotal = 0;

  @override
  void dispose() {
    _recorder.dispose();
    _transcript.dispose();
    _title.dispose();
    super.dispose();
  }

  bool get _busy => _phase != _Phase.input;

  // --- Voice capture -------------------------------------------------------

  Future<void> _toggleRecording() async {
    if (_transcribing || _starting) return;
    if (_recording) {
      await _stopAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _starting = true;
    });
    try {
      if (!await _recorder.hasPermission()) {
        setState(() {
          _error = 'Microphone permission denied.';
          _starting = false;
        });
        return;
      }
      final path = await recordingTargetPath();
      await _recorder.start(recordingConfig(), path: path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _starting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _starting = false;
        });
      }
    }
  }

  Future<void> _stopAndTranscribe() async {
    setState(() => _recording = false);
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }
    if (path == null) {
      setState(() => _error = 'Recording produced no audio.');
      return;
    }

    setState(() => _transcribing = true);
    try {
      final Uint8List bytes = await readRecordingBytes(path);
      final text = await _deepgram.transcribe(
        bytes,
        contentType: recordingContentType(),
      );
      if (!mounted) return;
      if (text.isNotEmpty) {
        // Append to whatever's already there so you can narrate in chunks.
        final existing = _transcript.text.trim();
        _transcript.text = existing.isEmpty ? text : '$existing $text';
        _transcript.selection = TextSelection.collapsed(
          offset: _transcript.text.length,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  // --- Compose + generate --------------------------------------------------

  Future<void> _createBook() async {
    final transcript = _transcript.text.trim();
    if (transcript.length < 10) {
      setState(() => _error = 'Tell a bit more of the story first.');
      return;
    }

    setState(() {
      _error = null;
      _phase = _Phase.composing;
      _statusLine = 'Weaving your story into pages…';
    });

    final repo = ref.read(storiesRepositoryProvider);
    ComposedStoryResult composed;
    try {
      composed = await repo.composeStory(
        transcript,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _phase = _Phase.input;
      });
      return;
    }

    // The book already exists and is readable; now bring it to life. Even if
    // some media fails, the reader degrades gracefully (audio/art are optional).
    if (!mounted) return;
    setState(() {
      _phase = _Phase.generating;
      _mediaDone = 0;
      // audio + illustration per page, plus the cover.
      _mediaTotal = composed.pages.length * 2 + 1;
      _statusLine = 'Painting illustrations & recording narration…';
    });

    var failures = 0;
    void tick() {
      if (mounted) setState(() => _mediaDone += 1);
    }

    // Narration: Deepgram handles plenty of concurrency — fire all at once.
    final audioJobs = composed.pages.map((p) async {
      try {
        await repo.generateAudio(p.id, text: p.text);
      } catch (_) {
        failures += 1;
      } finally {
        tick();
      }
    });

    // Illustrations: Midjourney has per-plan concurrency limits, so run them
    // through a small pool (cover included) rather than firing 10+ at once.
    final imageTasks = <Future<void> Function()>[
      () async {
        // Claude almost always supplies a cover prompt; fall back to a
        // title-based one so every book still gets cover art.
        final coverPrompt = composed.coverPrompt.isNotEmpty
            ? composed.coverPrompt
            : 'Book cover art for a children\'s storybook titled '
                '"${composed.title}", whimsical illustrated cover';
        try {
          await repo.generateCoverTexture(composed.storyId, coverPrompt);
        } catch (_) {
          failures += 1;
        } finally {
          tick();
        }
      },
      ...composed.pages.map((p) => () async {
            if (p.illustrationPrompt.isEmpty) {
              tick();
              return;
            }
            try {
              await repo.generateIllustration(p.id, p.illustrationPrompt);
            } catch (_) {
              failures += 1;
            } finally {
              tick();
            }
          }),
    ];

    await Future.wait([
      ...audioJobs,
      _runPooled(imageTasks, concurrency: 3),
    ]);

    // Refresh the list so the new book shows up, then open it.
    await ref.read(storiesProvider.notifier).refresh();
    if (!mounted) return;

    if (failures > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$failures of $_mediaTotal assets didn\'t generate — you can retry '
            'them in the editor.',
          ),
        ),
      );
    }
    context.go('/read/${composed.storyId}');
  }

  /// Runs [tasks] with at most [concurrency] in flight at once.
  Future<void> _runPooled(
    List<Future<void> Function()> tasks, {
    required int concurrency,
  }) async {
    var index = 0;
    Future<void> worker() async {
      while (index < tasks.length) {
        final task = tasks[index++];
        await task();
      }
    }

    await Future.wait(
      List.generate(concurrency.clamp(1, tasks.length), (_) => worker()),
    );
  }

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MagicScaffold(
      appBar: AppBar(
        title: const Text('Tell a Story'),
        leading: _busy
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/stories'),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _busy ? _buildProgress() : _buildInput(),
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          'Speak your story out loud — beginning to end — then I\'ll turn it '
          'into an illustrated, narrated book.',
          textAlign: TextAlign.center,
          style: AppTheme.serifFont(
            fontSize: 17,
            fontStyle: FontStyle.italic,
            color: MagicColors.textMuted,
          ),
        ),
        const SizedBox(height: 24),
        if (!_deepgram.hasKey) _missingKeyBanner(),
        _MicButton(
          recording: _recording,
          starting: _starting,
          transcribing: _transcribing,
          onTap: _toggleRecording,
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                style: AppTheme.bodyFont(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  border: InputBorder.none,
                ),
              ),
              const Divider(height: 8),
              TextField(
                controller: _transcript,
                minLines: 5,
                maxLines: 12,
                style: AppTheme.bodyFont(color: Colors.white),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText:
                      'Your story will appear here as you speak — or just type it.',
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _errorBanner(_error!),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _transcript.text.trim().length < 10 ? null : _createBook,
          style: FilledButton.styleFrom(
            backgroundColor: MagicColors.gold,
            foregroundColor: const Color(0xFF2A1B05),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.auto_stories),
          label: const Text('Create the book'),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final pct = _mediaTotal == 0 ? null : _mediaDone / _mediaTotal;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MagicWordmark(text: 'Dream Book', fontSize: 34),
          const SizedBox(height: 32),
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: _phase == _Phase.composing ? null : pct,
              color: MagicColors.gold,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _statusLine,
            textAlign: TextAlign.center,
            style: AppTheme.serifFont(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
          ),
          if (_phase == _Phase.generating) ...[
            const SizedBox(height: 12),
            Text(
              '$_mediaDone / $_mediaTotal',
              style: AppTheme.bodyFont(color: MagicColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _missingKeyBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'DEEPGRAM_KEY missing — voice capture is off, but you can still type '
          'your story below.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      );

  Widget _errorBanner(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      );
}

/// Big round mic toggle with a clear recording/transcribing state.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.recording,
    required this.starting,
    required this.transcribing,
    required this.onTap,
  });

  final bool recording;
  final bool starting;
  final bool transcribing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = transcribing
        ? 'Transcribing…'
        : starting
            ? 'Starting…'
            : recording
                ? 'Tap to stop'
                : 'Tap to speak';
    final busy = starting || transcribing;
    return Column(
      children: [
        GestureDetector(
          onTap: busy ? null : onTap,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: recording
                    ? [Colors.redAccent, Colors.red.shade900]
                    : const [MagicColors.gold, MagicColors.amber],
              ),
              boxShadow: [
                BoxShadow(
                  color: (recording ? Colors.redAccent : MagicColors.gold)
                      .withValues(alpha: 0.5),
                  blurRadius: 28,
                ),
              ],
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF2A1B05),
                    ),
                  )
                : Icon(
                    recording ? Icons.stop : Icons.mic,
                    size: 44,
                    color: const Color(0xFF2A1B05),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: AppTheme.bodyFont(color: MagicColors.textMuted)),
      ],
    );
  }
}

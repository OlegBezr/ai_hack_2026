import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models.dart';
import '../data/stories_repository.dart';

class StoryEditorScreen extends ConsumerStatefulWidget {
  const StoryEditorScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends ConsumerState<StoryEditorScreen> {
  StoriesRepository get _repo => ref.read(storiesRepositoryProvider);

  Story? _story;
  bool _loading = true;
  String? _error;

  final _titleController = TextEditingController();
  bool _savingTitle = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stories = await _repo.listStories();
      final story = stories.firstWhere(
        (s) => s.id == widget.storyId,
        orElse: () => throw StateError('Story not found'),
      );
      _titleController.text = story.title;
      if (!mounted) return;
      setState(() {
        _story = story;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        action: isError
            ? SnackBarAction(
                label: 'Copy',
                onPressed: () => Clipboard.setData(ClipboardData(text: msg)),
              )
            : null,
      ),
    );
  }

  Future<void> _saveTitle() async {
    final story = _story;
    if (story == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty || title == story.title) return;
    setState(() => _savingTitle = true);
    try {
      await _repo.updateStory(story.id, title: title);
      ref.read(storiesProvider.notifier).refresh();
      _snack('Title saved');
    } catch (e) {
      _snack('Failed to save title: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingTitle = false);
    }
  }

  Future<void> _addPage() async {
    final story = _story;
    if (story == null) return;
    final nextPos = story.pages.isEmpty
        ? 0
        : story.pages.map((p) => p.position).reduce((a, b) => a > b ? a : b) +
              1;
    try {
      await _repo.createPage(story.id, nextPos, '');
      await _load();
    } catch (e) {
      _snack('Failed to add page: $e', isError: true);
    }
  }

  Future<void> _deletePage(StoryPage page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete page?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deletePage(page.id);
      await _load();
    } catch (e) {
      _snack('Failed to delete page: $e', isError: true);
    }
  }

  /// Swaps the position values of two adjacent pages.
  Future<void> _movePage(int index, int delta) async {
    final story = _story;
    if (story == null) return;
    final target = index + delta;
    if (target < 0 || target >= story.pages.length) return;
    final a = story.pages[index];
    final b = story.pages[target];
    try {
      // Use a temporary position to dodge the unique(story_id, position) index.
      await _repo.updatePage(a.id, position: -1);
      await _repo.updatePage(b.id, position: a.position);
      await _repo.updatePage(a.id, position: b.position);
      await _load();
    } catch (e) {
      _snack('Failed to reorder: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/stories'),
        ),
        title: const Text('Edit story'),
      ),
      floatingActionButton: _story == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addPage,
              icon: const Icon(Icons.note_add),
              label: const Text('Add page'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final story = _story!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Story title',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _saveTitle(),
                  ),
                ),
                const SizedBox(width: 8),
                _savingTitle
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton.filled(
                        tooltip: 'Save title',
                        icon: const Icon(Icons.save),
                        onPressed: _saveTitle,
                      ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Pages', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (story.pages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No pages yet. Add one below.')),
              ),
            for (var i = 0; i < story.pages.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PageEditor(
                  key: ValueKey(story.pages[i].id),
                  page: story.pages[i],
                  index: i,
                  total: story.pages.length,
                  repo: _repo,
                  onChanged: _load,
                  onDelete: () => _deletePage(story.pages[i]),
                  onMoveUp: () => _movePage(i, -1),
                  onMoveDown: () => _movePage(i, 1),
                  snack: _snack,
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _PageEditor extends StatefulWidget {
  const _PageEditor({
    super.key,
    required this.page,
    required this.index,
    required this.total,
    required this.repo,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.snack,
  });

  final StoryPage page;
  final int index;
  final int total;
  final StoriesRepository repo;
  final Future<void> Function() onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final void Function(String, {bool isError}) snack;

  @override
  State<_PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<_PageEditor> {
  late final TextEditingController _textController;
  final _audioPlayer = AudioPlayer();

  bool _savingText = false;
  bool _generatingImage = false;
  bool _generatingAudio = false;

  String? _illustrationUrl;
  String? _audioUrl;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.page.text);
    _illustrationUrl = widget.page.illustrationUrl;
    _audioUrl = widget.page.audioUrl;
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveText() async {
    setState(() => _savingText = true);
    try {
      await widget.repo.updatePage(widget.page.id, text: _textController.text);
      widget.snack('Page saved');
    } catch (e) {
      widget.snack('Failed to save page: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingText = false);
    }
  }

  Future<void> _generateIllustration() async {
    final controller = TextEditingController(
      text: _textController.text.trim().isEmpty
          ? ''
          : _textController.text.trim(),
    );
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Illustration prompt'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Describe the illustration...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (prompt == null || prompt.isEmpty) return;

    setState(() => _generatingImage = true);
    try {
      final url = await widget.repo.generateIllustration(
        widget.page.id,
        prompt,
      );
      if (!mounted) return;
      setState(() => _illustrationUrl = url);
      widget.snack('Illustration generated');
    } catch (e) {
      widget.snack('Illustration failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingImage = false);
    }
  }

  Future<void> _generateAudio() async {
    setState(() => _generatingAudio = true);
    try {
      final text = _textController.text.trim();
      final url = await widget.repo.generateAudio(
        widget.page.id,
        text: text.isEmpty ? null : text,
      );
      if (!mounted) return;
      setState(() => _audioUrl = url);
      widget.snack('Audio generated');
    } catch (e) {
      widget.snack('Audio failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingAudio = false);
    }
  }

  Future<void> _playAudio() async {
    final url = _audioUrl;
    if (url == null) return;
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      widget.snack('Playback failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Page ${widget.index + 1}',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: widget.index == 0 ? null : widget.onMoveUp,
                ),
                IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: widget.index == widget.total - 1
                      ? null
                      : widget.onMoveDown,
                ),
                IconButton(
                  tooltip: 'Delete page',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            TextField(
              controller: _textController,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Page text...',
              ),
              onEditingComplete: _saveText,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _savingText ? null : _saveText,
                  icon: _savingText
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save text'),
                ),
                OutlinedButton.icon(
                  onPressed: _generatingImage ? null : _generateIllustration,
                  icon: _generatingImage
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: const Text('Generate illustration'),
                ),
                OutlinedButton.icon(
                  onPressed: _generatingAudio ? null : _generateAudio,
                  icon: _generatingAudio
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.record_voice_over),
                  label: const Text('Generate audio'),
                ),
              ],
            ),
            if (_illustrationUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _illustrationUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Text('Could not load illustration.'),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ],
            if (_audioUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Play audio',
                    onPressed: _playAudio,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _audioUrl!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
